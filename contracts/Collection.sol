// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Authorizable is Ownable {

    mapping(address => bool) public authorized;
    address[] public adminList;

    event AddAuthorized(address indexed _address);
    event RemoveAuthorized(address indexed _address, uint index);

    modifier onlyAuthorized() {
        require(authorized[msg.sender] || owner() == msg.sender,"Cow Authorizable: caller is not the SuperAdmin or Admin");
        _;
    }

    function addAuthorized(address _toAdd) onlyOwner() external {
        require(_toAdd != address(0),"Cow Authorizable: _toAdd isn't vaild address");
        require(!authorized[_toAdd],"Cow Authorizable: _toAdd is already added");
        authorized[_toAdd] = true;
        adminList.push(_toAdd);
        emit AddAuthorized(_toAdd);
    }

    function removeAuthorized(address _toRemove,uint _index) onlyOwner() external {
        require(_toRemove != address(0),"Cow Authorizable: _toRemove isn't vaild address");
        require(adminList[_index] == _toRemove,"Cow Authorizable: _index isn't valid index");
        authorized[_toRemove] = false;
        adminList[_index] = adminList[(adminList.length) - 1]; 
        adminList.pop();
        emit RemoveAuthorized(_toRemove,_index);
    }

    function getAdminList() public view returns(address[] memory ){
        return adminList;
    }
}

interface IERC2981 is IERC165 {
  
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (
        address receiver,
        uint256 royaltyAmount
    );
}

abstract contract ERC2981 is IERC2981, ERC165 {
    struct RoyaltyInfo {
        address receiver;
        uint96 royaltyFraction;
    }

    RoyaltyInfo private _defaultRoyaltyInfo;
    mapping(uint256 => RoyaltyInfo) private _tokenRoyaltyInfo;

    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC165) returns (bool) {
        return interfaceId == type(IERC2981).interfaceId || super.supportsInterface(interfaceId);
    }

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

        uint256 royaltyAmount = (_salePrice * royalty.royaltyFraction) / _feeDenominator();

        return (royalty.receiver, royaltyAmount);
    }

    function _feeDenominator() internal pure virtual returns (uint96) {
        return 10000;
    }

    function _setDefaultRoyalty(address receiver, uint96 feeNumerator) internal virtual {
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
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
        require(feeNumerator <= _feeDenominator(), "ERC2981: royalty fee will exceed salePrice");
        require(receiver != address(0), "ERC2981: Invalid parameters");

        _tokenRoyaltyInfo[tokenId] = RoyaltyInfo(receiver, feeNumerator);
    }

    function _resetTokenRoyalty(uint256 tokenId) internal virtual {
        delete _tokenRoyaltyInfo[tokenId];
    }
}

contract Collection is ERC721URIStorage, ERC2981, Authorizable {

    using Strings for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    uint256 public totalSupply;

    string private baseURI_;

    /**
     * @dev Mapping from holder address to their (enumerable) set of owned tokens.
     */
    mapping(address => EnumerableSet.UintSet) private _holderTokens;
    uint256 public counter;

    /**
     * @dev Sets base URI and initial royalty fees.
     */
    constructor(string memory _name,string memory _symbol,string memory _baseURI) ERC721(_name,_symbol) {
        _setBaseURI(_baseURI);
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
    function setRoyaltyforToken(uint256 _tokenId, address _receiver, uint96 _feeNumerator) public onlyOwner {
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
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) public onlyOwner {
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
    function tokenOfOwnerByIndex(address _owner, uint256 _index) public view returns (uint256){
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
    function mint(address _to,string memory _tokenURI) public onlyAuthorized() {
        require(_to != address(0),"WorldCow: _to address not valid");
        counter++;
        uint256 tokenId = counter;
        totalSupply = totalSupply + 1;
        _holderTokens[_to].add(tokenId);
        _safeMint(_to,tokenId);
        _setTokenURI(tokenId,_tokenURI);
    }


    /**
     * @dev Burns token of entered token id.
     */
    function burn(uint _tokenId) public {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "WorldCow: burn caller is not owner nor approved");
        _holderTokens[msg.sender].remove(_tokenId);
        _burn(_tokenId);
    }

    /**
     * @dev Transfers token from 'from' address to 'to' address.
     */
    function transferFrom(address from,address to,uint256 tokenId) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "WorldCow: transfer caller is not owner nor approved");
        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);
        _transfer(from, to, tokenId);
    }
    
    /**
     * @dev Safe transfers token from 'from' address to 'to' address.
     */
    function safeTransferFrom(address from,address to,uint256 tokenId) public override {
        safeTransferFrom(from, to, tokenId, "");
    }
    
    /**
     * @dev Safe transfers token from 'from' address to 'to' address.
     */
    function safeTransferFrom(address from,address to,uint256 tokenId,bytes memory _data) public override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "WorldCow: transfer caller is not owner nor approved");
        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);
        _safeTransfer(from, to, tokenId, _data);
    }
    
    /**
     * @dev Returns an array of tokens owned by the argument address.
     */
    function getTokens(address _address) public view returns(uint256[] memory){
        return _holderTokens[_address].values();
    }

}