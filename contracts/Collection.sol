// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

interface IERC2981 is IERC165 {
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        returns (address receiver, uint256 royaltyAmount);
}

contract Authorizable is Ownable {
    mapping(address => bool) public authorized;
    address[] public adminList;

    event AddAuthorized(address indexed _address);
    event RemoveAuthorized(address indexed _address, uint256 index);

    modifier onlyAuthorized() {
        require(
            authorized[msg.sender] || owner() == msg.sender,
            "Collection Authorized: caller is not the SuperAdmin or Admin"
        );
        _;
    }

    /**
     * @dev Add a sub admin.
     */

    function addAuthorized(address _toAdd) external onlyOwner {
        require(
            _toAdd != address(0),
            "Collection Authorized: _toAdd isn't vaild address"
        );
        require(
            !authorized[_toAdd],
            "Collection Authorized: _toAdd is already added"
        );
        authorized[_toAdd] = true;
        adminList.push(_toAdd);
        emit AddAuthorized(_toAdd);
    }

    /**
     * @dev remove a sub admin.
     */

    function removeAuthorized(address _toRemove, uint256 _index)
        external
        onlyOwner
    {
        require(
            _toRemove != address(0),
            "Collection Authorized: _toRemove isn't vaild address"
        );
        require(
            adminList[_index] == _toRemove,
            "Collection Authorized: _index isn't valid index"
        );
        authorized[_toRemove] = false;
        adminList[_index] = adminList[(adminList.length) - 1];
        adminList.pop();
        emit RemoveAuthorized(_toRemove, _index);
    }

    /**
     * @dev get sub admin list.
     */

    function getAdminList() public view returns (address[] memory) {
        return adminList;
    }
}


abstract contract ERC2981 is IERC2981, ERC165 {
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    RoyaltyInfo private _defaultRoyaltyInfo;
    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Return token royality info.
     * @dev reciver royalty reciver address
     */

    function royaltyInfo(uint256 _tokenId, uint256 _salePrice)
        external
        view
        virtual
        override
        returns (address, uint256)
    {
        RoyaltyInfo memory royalty = _tokenRoyaltyInfo[_tokenId];

        if (royalty.receiver == address(0)) {
            royalty = _defaultRoyaltyInfo;
        }

        uint256 royaltyAmount = (_salePrice * royalty.royaltyFraction) /
            _feeDenominator();

        return (royalty.receiver, royaltyAmount);
    }

    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    function _setDefaultRoyalty(address receiver, uint96 feeNumerator)
        internal
        virtual
    {
        require(
            feeNumerator <= _feeDenominator(),
            "ERC2981: royalty fee will exceed salePrice"
        );
        require(receiver != address(0), "ERC2981: invalid receiver");

        _defaultRoyaltyInfo = RoyaltyInfo(receiver, feeNumerator);
    }

    function _deleteDefaultRoyalty() internal virtual {
        delete _defaultRoyaltyInfo;
    }

    function _setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) internal virtual {
        require(
            feeNumerator <= _feeDenominator(),
            "ERC2981: royalty fee will exceed salePrice"
        );
        require(receiver != address(0), "ERC2981: Invalid parameters");

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }

    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
    }
}

contract Whitelist is Ownable {
    mapping(address => bool) private whitelistedMap;
    event Whitelisted(address indexed account, bool isWhitelisted);

    function whitelisted(address _address) public view returns (bool) {
        return whitelistedMap[_address];
    }

    /**
     * @dev Whitelist MarketPlace and any token approval contract address.
     */
    function addAddress(address _address) public onlyOwner {
        require(whitelistedMap[_address] != true,"Collection WhiteList: address already whitelisted");
        whitelistedMap[_address] = true;
        emit Whitelisted(_address, true);
    }

    /**
     * @dev remove from Whitelist.
     */

    function removeAddress(address _address) public onlyOwner {
        require(whitelistedMap[_address] != false,"Collection WhiteList: address already removed");
        whitelistedMap[_address] = false;
        emit Whitelisted(_address, false);
    }
}

contract Collection is ERC721URIStorage, ERC2981, Authorizable, Whitelist {
    using Address for address;
    using Strings for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public totalSupply;

    string private baseURI_;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    /**
     * @dev Mapping from holder address to their (enumerable) set of owned tokens.
     */
    mapping(address => EnumerableSet.UintSet) private _holderTokens;
    uint256 public counter;

    /**
     * @dev Sets base URI and initial royalty fees.
     */
    constructor(
        string memory _name,
        string memory _symbol,
        string memory __baseURI
    ) ERC721(_name, _symbol) {
        _setBaseURI(__baseURI);
    }

    /**
     * @dev returns true if the contract supports the interface with entered bytecode.
     * @dev 0x2a55205a to test eip 2981
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Sets the royalty info for any token.
     */
    function setRoyaltyforToken(
        uint256 _tokenId,
        address _receiver,
        uint96 _feeNumerator
    ) public onlyOwner {
        _setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
    }

    /**
     * @dev Deletes the royalty info for any token.
     */
    function resetTokenRoyalty(uint256 _tokenId) public onlyOwner {
        _resetTokenRoyalty(_tokenId);
    }

    /**
     * @dev Sets the default royalty info.
     */
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator)
        public
        onlyOwner
    {
        _setDefaultRoyalty(_receiver, _feeNumerator);
    }

    /**
     * @dev Deletes the default royalty.
     */
    function deleteDefaultRoyalty() public onlyOwner {
        _deleteDefaultRoyalty();
    }

    /**
     * @dev Returns the token id from the array of tokens owned by the argument address present at the argument index.
     */
    function tokenOfOwnerByIndex(address _owner, uint256 _index)
        public
        view
        returns (uint256)
    {
        return _holderTokens[_owner].at(_index);
    }

    /**
     * @dev Sets base URI.
     */
    function _setBaseURI(string memory _baseTokenURI) internal {
        baseURI_ = _baseTokenURI;
    }

    /**
     * @dev Mints single token.
     *
     */
    function mint(address _to, string memory _tokenURI) public onlyAuthorized {
        require(_to != address(0), "Collection: _to address not valid");
        counter++;
        uint256 tokenId = counter;
        totalSupply = totalSupply + 1;
        _holderTokens[_to].add(tokenId);
        _safeMint(_to, tokenId);
        _setTokenURI(tokenId, _tokenURI);
    }

    /**
     * @dev Mints cards in batch on 'to' address.
     */
    function batchMint(
        address _to,
        uint256 _numberOfToken,
        string[] memory _tokenURI
    ) external onlyAuthorized {
        for (uint256 i = 0; i < _numberOfToken; i++) {
            mint(_to, _tokenURI[i]);
        }
    }

    /**
     * @dev Burns token of entered token id.
     */
    function burn(uint256 _tokenId) public {
        require(
            _isApprovedOrOwner(_msgSender(), _tokenId),
            "Collection: burn caller is not owner nor approved"
        );
        _holderTokens[msg.sender].remove(_tokenId);
        _burn(_tokenId);
    }

    /// @notice disable approve
    function approve(address to, uint256 tokenId) public override {
        if (to.isContract()) {
            require(whitelisted(to), "Only whitelist is allowed");
        }
        super.approve(to, tokenId);
    }

    /// @notice disable owner to set approve for those operator not in whitelist
    function setApprovalForAll(address operator, bool approved)
        public
        override
    {
        if (operator.isContract()) {
            require(whitelisted(operator), "Only whitelist is allowed");
        }
        super.setApprovalForAll(operator, approved);
    }

    /**
     * @dev Transfers token from 'from' address to 'to' address.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Collection: transfer caller is not owner nor approved"
        );
        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);
        _transfer(from, to, tokenId);
    }

    /**
     * @dev Safe transfers token from 'from' address to 'to' address.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        safeTransferFrom(from, to, tokenId, "");
    }

    /**
     * @dev Safe transfers token from 'from' address to 'to' address.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "Collection: transfer caller is not owner nor approved"
        );
        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);
        _safeTransfer(from, to, tokenId, _data);
    }

    /**
     * @dev Transfer token Ownership.
     */
    function transferTokenOwnership(uint256 tokenId, address newOwner) external onlyOwner {
        _holderTokens[msg.sender].remove(tokenId);
        _holderTokens[newOwner].add(tokenId);
        super._transfer(msg.sender, newOwner, tokenId);
    }

    /**
     * @dev Returns the base URI.
     */
    function _baseURI() internal view override returns (string memory) {
        return baseURI_;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721URIStorage: URI query for nonexistent token"
        );

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return
            bytes(base).length > 0
                ? string(abi.encodePacked(base, tokenId.toString(), ".json"))
                : "";
    }

    /**
     * @dev Returns an array of tokens owned by the argument address.
     */
    function getTokens(address _address)
        public
        view
        returns (uint256[] memory)
    {
        return _holderTokens[_address].values();
    }
}
