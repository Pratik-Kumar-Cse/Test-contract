// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import  "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import  "@openzeppelin/contracts/utils/Counters.sol";

/**
 * @title Interface for Auction Houses
 */
interface IAuctionHouse {
    struct Auction {
        // ID for the ERC721 token
        uint256 tokenId;
        // Address for the ERC721 contract
        address tokenContract;
        // The current highest bid amount
        uint256 amount;
        // The length of time to run the auction for, after the first bid was made
        uint256 duration;
        // The time of the first bid
        uint256 firstBidTime;
        // The minimum price of the first bid
        uint256 reservePrice;
        // The sale percentage to send to the curator
        uint8 curatorFeePercentage;//owner of the nft percentage
        // The address that should receive the funds once the NFT is sold.
        address tokenOwner;//Owner of the token address
        // The address of the current highest bid
        address payable bidder;//address of current highest bidder
        // The address of the ERC-20 currency to run the auction with.
        // If set to 0x0, the auction will be run in ETH
        address auctionCurrency;
    }

    struct DutchAuction{
        // ID for the ERC721 token
        uint256 tokenId;
        // Address for the ERC721 contract
        address tokenContract;

        uint256 discountRate;

        uint256 startAt;
        // The length of time to run the auction for, after the first bid was made
        uint256 duration;
        // The minimum price of the first bid
        uint256 reservePrice;
        // The sale percentage to send to the curator
        uint8 curatorFeePercentage;
        // The address that should receive the funds once the NFT is sold.
        address tokenOwner;
        // The address of the ERC-20 currency to run the auction with.
        // If set to 0x0, the auction will be run in ETH
        address auctionCurrency;

    }

    struct Order{
        // ID for the ERC721 token
        uint256 tokenId;
        // Address for the ERC721 contract
        address tokenContract;
        // The minimum price of the first bid
        uint256 reservePrice;
        // The sale percentage to send to the curator
        uint8 curatorFeePercentage;
        // The address that should receive the funds once the NFT is sold.
        address tokenOwner;
        // The address of the ERC-20 currency to run the sale with.
        // If set to 0x0, the auction will be run in ETH
        address currency;
    }

    event AuctionCreated(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed tokenContract,
        uint256 duration,
        uint256 reservePrice,
        address tokenOwner,
        address curator,
        uint8 curatorFeePercentage,
        address auctionCurrency
    );

    event AuctionApprovalUpdated(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed tokenContract,
        bool approved
    );

    event AuctionReservePriceUpdated(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed tokenContract,
        uint256 reservePrice
    );

    event AuctionBid(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed tokenContract,
        address sender,
        uint256 value,
        bool firstBid,
        bool extended
    );

    event AuctionDurationExtended(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed tokenContract,
        uint256 duration
    );

    event AuctionEnded(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed tokenContract,
        address tokenOwner,
        address curator,
        address winner,
        uint256 amount,
        uint256 curatorFee,
        address auctionCurrency
    );

    event AuctionCanceled(
        uint256 indexed auctionId,
        uint256 indexed tokenId,
        address indexed tokenContract,
        address tokenOwner
    );

    function setAuctionReservePrice(uint256 auctionId, uint256 reservePrice) external;

    function createBid(uint256 auctionId, uint256 amount) external payable;

    function endAuction(uint256 auctionId) external;

    function cancelAuction(uint256 auctionId) external;
}

///
/// @dev Interface for the NFT Royalty Standard
///
interface IERC2981 is IERC721 {
    /// ERC165 bytes to add to interface array - set in parent contract
    /// implementing this standard
    ///
    /// bytes4(keccak256("royaltyInfo(uint256,uint256)")) == 0x2a55205a
    /// bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;
    /// _registerInterface(_INTERFACE_ID_ERC2981);

    /// @notice Called with the sale price to determine how much royalty
    //          is owed and to whom.
    /// @param _tokenId - the NFT asset queried for royalty information
    /// @param _salePrice - the sale price of the NFT asset specified by _tokenId
    /// @return receiver - address of who should be sent the royalty payment
    /// @return royaltyAmount - the royalty payment amount for _salePrice
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (
        address receiver,//receiver address of the royality info 
        uint256 royaltyAmount//amount he need to pay
    );
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint wad) external;
    function transfer(address to, uint256 value) external returns (bool);
}

/**
 * @title An open auction house, enabling collectors and curators to run their own auctions
 */
contract MarketPlace is IAuctionHouse, ReentrancyGuard {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    // The minimum amount of time left in an auction after a new bid is created
    uint256 public timeBuffer;//after every bid we will wait this much time

    // The minimum percentage difference between the last bid amount and the current bid.
    uint8 public minBidIncrementPercentage;//every time the users bid ,how much they need to pay the extra from last bidder to consider as bidder

    // The address of the zora protocol to use via this contract
    address public collection;

    // / The address of the WETH contract, so that any ETH transferred can be handled as an ERC-20
    address public wethAddress;

    // A mapping of all of the auctions currently running.
    mapping(uint256 => IAuctionHouse.Auction) public auctions;//order mapping

    // A mapping of all of the auctions currently running.
    mapping(uint256 => IAuctionHouse.DutchAuction) public dutchAuctions;

    // A mapping of all of the order currently running.
    mapping(uint256 => IAuctionHouse.Order) public saleOrder;//order mapping 

    bytes4 constant interfaceId = 0x80ac58cd; // 721 interface id
    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    Counters.Counter private _auctionIdTracker;
    Counters.Counter private _dutchAuctionIdTracker;
    Counters.Counter private _saleOrderTracker;


    address public curator;
    /**
     * @notice Require that the specified auction exists
     */
    modifier auctionExists(uint256 auctionId) {
        require(_exists(auctionId,true), "Auction doesn't exist");
        _;
    }//function for auction exists?

    /**
     * @notice Require that the specified order exists
     */
    modifier orderExists(uint256 orderId) {
        require(_exists(orderId,false), "Auction doesn't exist");
        _;
    }

    /**
     * @notice Require that the specified order exists
     */
    modifier dutchAuctionExists(uint256 auctionId) {
        require(dutchAuctions[auctionId].tokenOwner != address(0), "Auction doesn't exist");
        _;
    }

    /*
     * Constructor
     */
    constructor(address _collection, address _weth) {
        require(
            IERC165(_collection).supportsInterface(interfaceId),//This collection contract supports this interfaid
            "Doesn't support NFT interface"
        );
        collection = _collection;//address of the collection contract
        wethAddress = _weth;//weth address
        timeBuffer = 15 * 60; // extend 15 minutes after every bid made in last 15 minutes
        minBidIncrementPercentage = 5; // 5%
    }


    /**
     * @notice Create an Sale oder.
     */
    function createSaleOrder(
        uint256 tokenId,
        address tokenContract,
        uint256 reservePrice,
        address currency
    ) public nonReentrant returns (uint256) {
        require(
            IERC165(tokenContract).supportsInterface(interfaceId),//will this token contract supports the interface
            "tokenContract does not support ERC721 interface"
        );
        address tokenOwner = IERC721(tokenContract).ownerOf(tokenId);//get the owner of the tokenId
        require(msg.sender == IERC721(tokenContract).getApproved(tokenId) || msg.sender == tokenOwner, "Caller must be approved or owner for token id");//caller needs to be approved or the owner
        uint256 oderId = _saleOrderTracker.current();//increase the selll order
        saleOrder[oderId] = Order({
            tokenId: tokenId,
            tokenContract: tokenContract,
            reservePrice: reservePrice,
            curatorFeePercentage: 2,
            tokenOwner: tokenOwner,
            currency: currency
        });
        IERC721(tokenContract).transferFrom(tokenOwner, address(this), tokenId);//transfer the token from the owner to this address
        _auctionIdTracker.increment();//increament the auction
        return oderId;
    }

    /**
     * @notice Cancel an order.
     * @dev Transfers the NFT back to the auction creator and emits an AuctionCanceled event
     */
    function cancelOrder(uint256 orderId) external nonReentrant orderExists(orderId) {
        require(
            auctions[orderId].tokenOwner == msg.sender,
            "Can only be called by auction creator or curator"
        );//caller needs to be owner
        _cancelOrder(orderId);
    }

    /**
     * @notice buy order.
     
     */
    function buyOrder(uint256 orderId) external payable auctionExists(orderId) nonReentrant {
        uint256 curatorFee = 0;
        uint256 royaltiyFee = 0;
        uint256 tokenOwnerProfit = saleOrder[orderId].reservePrice;
        _handleIncomingBid(tokenOwnerProfit, saleOrder[orderId].currency);//transfer the amount from user to this address
        IERC721(saleOrder[orderId].tokenContract).safeTransferFrom(address(this), msg.sender, saleOrder[orderId].tokenId);//give the token to the user
        if(curator != address(0)) {
            curatorFee = tokenOwnerProfit.mul(saleOrder[orderId].curatorFeePercentage).div(100);//give the curator percent from the user paid
            _handleOutgoingBid(curator, curatorFee, saleOrder[orderId].currency);//transfer the amount to the curator
        }
        if(checkRoyalties(saleOrder[orderId].tokenContract)){
            (address reciver,uint royaltyAmount) = IERC2981(saleOrder[orderId].tokenContract).royaltyInfo(saleOrder[orderId].tokenId,tokenOwnerProfit);
            royaltiyFee = tokenOwnerProfit.mul(saleOrder[orderId].curatorFeePercentage).div(100);//this is not right
            _handleOutgoingBid(reciver, royaltyAmount, saleOrder[orderId].currency);//give the royality to the original owner
        }
        tokenOwnerProfit = tokenOwnerProfit.sub(curatorFee.add(royaltiyFee));//the amount which we sold for in that some will go to the platform and some will go to the royality to the first user
        _handleOutgoingBid(saleOrder[orderId].tokenOwner, tokenOwnerProfit, saleOrder[orderId].currency);//send the owner this much amount 
        _handleOutgoingBid(msg.sender, msg.value - (tokenOwnerProfit + curatorFee), saleOrder[orderId].currency);//send the remianing
        delete saleOrder[orderId];
    }

    /**
     * @notice Create an auction.
     * @dev Store the auction details in the auctions mapping and emit an AuctionCreated event.
     * If there is no curator, or if the curator is the auction creator, automatically approve the auction.
     */
    function createAuction(
        uint256 tokenId,
        address tokenContract,
        uint256 duration,
        uint256 reservePrice,
        address auctionCurrency
    ) public nonReentrant returns (uint256) {
        require(
            IERC165(tokenContract).supportsInterface(interfaceId),
            "tokenContract does not support ERC721 interface"
        );
        address tokenOwner = IERC721(tokenContract).ownerOf(tokenId);
        require(msg.sender == IERC721(tokenContract).getApproved(tokenId) || msg.sender == tokenOwner, "Caller must be approved or owner for token id");
        uint256 auctionId = _auctionIdTracker.current();
        auctions[auctionId] = Auction({
            tokenId: tokenId,
            tokenContract: tokenContract,
            amount: 0,
            duration: duration,
            firstBidTime: 0,
            reservePrice: reservePrice,
            curatorFeePercentage: 5,
            tokenOwner: tokenOwner,//token owner
            bidder: payable(address(0)),
            auctionCurrency: auctionCurrency
        });

        IERC721(tokenContract).transferFrom(tokenOwner, address(this), tokenId);//get the tokenid from the user to this contract
        _auctionIdTracker.increment();//increment the  auction id

        emit AuctionCreated(auctionId, tokenId, tokenContract, duration, reservePrice, tokenOwner, curator, 5, auctionCurrency);
        return auctionId;
    }

    function setAuctionReservePrice(uint256 auctionId, uint256 reservePrice) external override auctionExists(auctionId) {
        require(msg.sender == auctions[auctionId].tokenOwner, "Must be auction curator or token owner");
        require(auctions[auctionId].firstBidTime == 0, "Auction has already started");//if anyone bid the bid time will change
        auctions[auctionId].reservePrice = reservePrice;//change the reserve price
        emit AuctionReservePriceUpdated(auctionId, auctions[auctionId].tokenId, auctions[auctionId].tokenContract, reservePrice);
    }


    /**
     * @notice Create an auction.
     * @dev Store the auction details in the auctions mapping and emit an AuctionCreated event.
     * If there is no curator, or if the curator is the auction creator, automatically approve the auction.
     */
    function createDutchAuction(
        uint256 tokenId,
        address tokenContract,
        uint256 duration,
        uint256 reservePrice,
        uint256 discountRate,
        address auctionCurrency
    ) public nonReentrant returns (uint256) {
        require(
            IERC165(tokenContract).supportsInterface(interfaceId),
            "tokenContract does not support ERC721 interface"
        );
        require(reservePrice >= discountRate * duration,"reservePrice less than discout");
        address tokenOwner = IERC721(tokenContract).ownerOf(tokenId);
        require(msg.sender == IERC721(tokenContract).getApproved(tokenId) || msg.sender == tokenOwner, "Caller must be approved or owner for token id");
        uint256 auctionId = _dutchAuctionIdTracker.current();
        dutchAuctions[auctionId] = DutchAuction({
            tokenId: tokenId,
            tokenContract: tokenContract,
            startAt: block.timestamp,
            duration: duration,
            reservePrice: reservePrice,
            discountRate: discountRate,
            curatorFeePercentage: 5,
            tokenOwner: tokenOwner,
            auctionCurrency: auctionCurrency
        });
        IERC721(tokenContract).transferFrom(tokenOwner, address(this), tokenId);
        _dutchAuctionIdTracker.increment();
        emit AuctionCreated(auctionId, tokenId, tokenContract, duration, reservePrice, tokenOwner, curator, 5, auctionCurrency);
        return auctionId;
    }

    /**
     * @notice Cancel an Dutch auction.
     * @dev Transfers the NFT back to the auction creator and emits an AuctionCanceled event
     */
    function cancelDutchAuction(uint256 auctionId) external nonReentrant dutchAuctionExists(auctionId) {
        require(
            dutchAuctions[auctionId].tokenOwner == msg.sender,
            "Can only be called by auction creator or curator"
        );
        _cancelDutchAuction(auctionId);
    }

    /**
     * @notice  auction, finalizing the bid on Zora if applicable and paying out the respective parties
     */
    function buyDutchAuction(uint256 auctionId) payable external dutchAuctionExists(auctionId) nonReentrant {
        require(
            block.timestamp <
            dutchAuctions[auctionId].startAt.add(auctions[auctionId].duration),
            "Auction hasn't completed"
        );
        uint curatorFee = 0;
        uint royaltiyFee = 0;
        uint256 tokenOwnerProfit = getPrice(auctionId);
        _handleIncomingBid(tokenOwnerProfit, dutchAuctions[auctionId].auctionCurrency);
        IERC721(dutchAuctions[auctionId].tokenContract).safeTransferFrom(address(this), msg.sender, dutchAuctions[auctionId].tokenId);
        if(curator != address(0)) {
            curatorFee = tokenOwnerProfit.mul(dutchAuctions[auctionId].curatorFeePercentage).div(100);
            _handleOutgoingBid(curator, curatorFee, auctions[auctionId].auctionCurrency);
        }
        if(checkRoyalties(dutchAuctions[auctionId].tokenContract)){
            (address reciver,uint royaltyAmount) = IERC2981(dutchAuctions[auctionId].tokenContract).royaltyInfo(dutchAuctions[auctionId].tokenId,tokenOwnerProfit);
            royaltiyFee = tokenOwnerProfit.mul(dutchAuctions[auctionId].curatorFeePercentage).div(100);
            _handleOutgoingBid(reciver, royaltyAmount, dutchAuctions[auctionId].auctionCurrency);
        }
        tokenOwnerProfit = tokenOwnerProfit.sub(curatorFee.add(royaltiyFee));
        _handleOutgoingBid(auctions[auctionId].tokenOwner, tokenOwnerProfit, auctions[auctionId].auctionCurrency);
        delete dutchAuctions[auctionId];
    }
    
    /**
     * @notice Create a bid on a token, with a given amount.
     * @dev If provided a valid bid, transfers the provided amount to this contract.
     * If the auction is run in native ETH, the ETH is wrapped so it can be identically to other
     * auction currencies in this contract.
     */
    function createBid(uint256 auctionId, uint256 amount)
    external
    override
    payable
    auctionExists(auctionId)
    nonReentrant
    {
        address payable lastBidder = auctions[auctionId].bidder;//get the last bidder
        require(
            auctions[auctionId].firstBidTime == 0 ||
            block.timestamp <
            auctions[auctionId].firstBidTime.add(auctions[auctionId].duration),
            "Auction expired"//the next bid needs to be happended in less than 15 min
        );
        require(
            amount >= auctions[auctionId].reservePrice,
                "Must send at least reservePrice"//the amount needs to be greater than the reserve price
        );
        require(
            amount >= auctions[auctionId].amount.add(
                auctions[auctionId].amount.mul(minBidIncrementPercentage).div(100)
            ),
            "Must send more than last bid by minBidIncrementPercentage amount"
        );//the amount but be greater than 5% from the last bid

        // If this is the first valid bid, we should set the starting time now.
        // If it's not, then we should refund the last bidder
        if(auctions[auctionId].firstBidTime == 0) {
            auctions[auctionId].firstBidTime = block.timestamp;
        } else if(lastBidder != address(0)) {
            _handleOutgoingBid(lastBidder, auctions[auctionId].amount, auctions[auctionId].auctionCurrency);//send the amount to the last bidder because we got the highest bid then him
        }

        _handleIncomingBid(amount, auctions[auctionId].auctionCurrency);//get the amount into the contract

        auctions[auctionId].amount = amount;//this is the amount i have bidded
        auctions[auctionId].bidder = payable(msg.sender);//store the msg

        bool extended = false;
        // at this point we know that the timestamp is less than start + duration (since the auction would be over, otherwise)
        // (10:30+15min)--->10:45 min
        //  
        // we want to know by how much the timestamp is less than start + duration
        // if the difference is less than the timeBuffer, increase the duration by the timeBuffer
        //
        if (
            auctions[auctionId].firstBidTime.add(auctions[auctionId].duration).sub(
                block.timestamp
            ) < timeBuffer//if there is no time for the next bid,means if someone had created the bid last less than 15 secs from the duration and there is only one bid happened inthis auction
        ) {
            // Playing code golf for gas optimization:
            // uint256 expectedEnd = auctions[auctionId].firstBidTime.add(auctions[auctionId].duration);//it needs to be ended 
            // uint256 timeRemaining = expectedEnd.sub(block.timestamp);
            // uint256 timeToAdd = timeBuffer.sub(timeRemaining);
            // uint256 newDuration = auctions[auctionId].duration.add(timeToAdd);//extend the time by the 15 min
            uint256 oldDuration = auctions[auctionId].duration;
            auctions[auctionId].duration =
                oldDuration.add(timeBuffer.sub(auctions[auctionId].firstBidTime.add(oldDuration).sub(block.timestamp)));
            extended = true;
        }

        emit AuctionBid(
            auctionId,
            auctions[auctionId].tokenId,
            auctions[auctionId].tokenContract,
            msg.sender,
            amount,
            lastBidder == address(0), // firstBid boolean
            extended
        );

        if (extended) {
            emit AuctionDurationExtended(
                auctionId,
                auctions[auctionId].tokenId,
                auctions[auctionId].tokenContract,
                auctions[auctionId].duration
            );
        }
    }

    /**
     * @notice End an auction, finalizing the bid on Zora if applicable and paying out the respective parties.
     * @dev If for some reason the auction cannot be finalized (invalid token recipient, for example),
     * The auction is reset and the NFT is transferred back to the auction creator.
     */
    function endAuction(uint256 auctionId) external override auctionExists(auctionId) nonReentrant {
        require(
            uint256(auctions[auctionId].firstBidTime) != 0,
            "Auction hasn't begun"
        );
        require(
            block.timestamp >=
            auctions[auctionId].firstBidTime.add(auctions[auctionId].duration),
            "Auction hasn't completed"
        );

        address currency = auctions[auctionId].auctionCurrency == address(0) ? wethAddress : auctions[auctionId].auctionCurrency;
        uint256 curatorFee = 0;
        uint256 royaltiyFee = 0;

        uint256 tokenOwnerProfit = auctions[auctionId].amount;
        
            // Otherwise, transfer the token to the winner and pay out the participants below
        try IERC721(auctions[auctionId].tokenContract).safeTransferFrom(address(this), auctions[auctionId].bidder, auctions[auctionId].tokenId) {} catch {
            _handleOutgoingBid(auctions[auctionId].bidder, auctions[auctionId].amount, auctions[auctionId].auctionCurrency);//we will send his money back to the bidder
            _cancelAuction(auctionId);//and end the auction
            return;
        }
        
        if(curator != address(0)) {
            curatorFee = tokenOwnerProfit.mul(auctions[auctionId].curatorFeePercentage).div(100);
            _handleOutgoingBid(curator, curatorFee, auctions[auctionId].auctionCurrency);
        }
        if(checkRoyalties(auctions[auctionId].tokenContract)){
            (address reciver,uint royaltyAmount) = IERC2981(auctions[auctionId].tokenContract).royaltyInfo(auctions[auctionId].tokenId,tokenOwnerProfit);
            royaltiyFee = tokenOwnerProfit.mul(auctions[auctionId].curatorFeePercentage).div(100);//why we are using this 
            _handleOutgoingBid(reciver, royaltyAmount, auctions[auctionId].auctionCurrency);
        }
        tokenOwnerProfit = tokenOwnerProfit.sub(curatorFee.add(royaltiyFee));
        _handleOutgoingBid(auctions[auctionId].tokenOwner, tokenOwnerProfit, auctions[auctionId].auctionCurrency);

        emit AuctionEnded(
            auctionId,
            auctions[auctionId].tokenId,
            auctions[auctionId].tokenContract,
            auctions[auctionId].tokenOwner,
            curator,
            auctions[auctionId].bidder,
            tokenOwnerProfit,
            curatorFee,
            currency
        );
        delete auctions[auctionId];
    }

    /**
     * @notice Cancel an auction.
     * @dev Transfers the NFT back to the auction creator and emits an AuctionCanceled event
     */
    function cancelAuction(uint256 auctionId) external override nonReentrant auctionExists(auctionId) {
        require(
            auctions[auctionId].tokenOwner == msg.sender,
            "Can only be called by auction creator or curator"
        );
        require(
            uint256(auctions[auctionId].firstBidTime) == 0,
            "Can't cancel an auction once it's begun"
        );
        _cancelAuction(auctionId);
    }

    function checkRoyalties(address _contract) internal view returns(bool) {
        (bool success) = IERC165(_contract).supportsInterface(_INTERFACE_ID_ERC2981);
        return success;
    }

    /**
     * @dev Given an amount and a currency, transfer the currency to this contract.
     * If the currency is ETH (0x0), attempt to wrap the amount as WETH
     */
    function _handleIncomingBid(uint256 amount, address currency) internal {
        // If this is an ETH bid, ensure they sent enough and convert it to WETH under the hood
        if(currency == address(0)) {
            require(msg.value == amount, "Sent ETH Value does not match specified bid amount");
            IWETH(wethAddress).deposit{value: amount}();//we will store weth tokens
        } else {
            // We must check the balance that was actually transferred to the auction,
            // as some tokens impose a transfer fee and would not actually transfer the
            // full amount to the market, resulting in potentally locked funds
            IERC20 token = IERC20(currency);
            uint256 beforeBalance = token.balanceOf(address(this));
            token.safeTransferFrom(msg.sender, address(this), amount);//transfer from the user to this address
            uint256 afterBalance = token.balanceOf(address(this));
            require(beforeBalance.add(amount) == afterBalance, "Token transfer call did not transfer expected amount");
        }
    }

    function _handleOutgoingBid(address to, uint256 amount, address currency) internal {
        // If the auction is in ETH, unwrap it from its underlying WETH and try to send it to the recipient.
        if(currency == address(0)) {
            IWETH(wethAddress).withdraw(amount);

            // If the ETH transfer fails (sigh), rewrap the ETH and try send it as WETH.
            if(!_safeTransferETH(to, amount)) {
                IWETH(wethAddress).deposit{value: amount}();
                IERC20(wethAddress).safeTransfer(to, amount);
            }
        } else {
            IERC20(currency).safeTransfer(to, amount);
        }
    }

    function _safeTransferETH(address to, uint256 value) internal returns (bool) {
        (bool success, ) = to.call{value: value}(new bytes(0));
        return success;
    }

    function _cancelAuction(uint256 auctionId) internal {
        address tokenOwner = auctions[auctionId].tokenOwner;
        IERC721(auctions[auctionId].tokenContract).safeTransferFrom(address(this), tokenOwner, auctions[auctionId].tokenId);

        emit AuctionCanceled(auctionId, auctions[auctionId].tokenId, auctions[auctionId].tokenContract, tokenOwner);
        delete auctions[auctionId];
    }

    function _cancelDutchAuction(uint256 auctionId) internal {
        address tokenOwner = auctions[auctionId].tokenOwner;
        IERC721(dutchAuctions[auctionId].tokenContract).safeTransferFrom(address(this), tokenOwner, dutchAuctions[auctionId].tokenId);
        delete dutchAuctions[auctionId];
    }

    function _cancelOrder(uint256 orderId) internal {
        address tokenOwner = saleOrder[orderId].tokenOwner;
        IERC721(saleOrder[orderId].tokenContract).safeTransferFrom(address(this), tokenOwner, saleOrder[orderId].tokenId);
        delete saleOrder[orderId];
    }

    function _exists(uint256 id,bool isAuction) internal view returns(bool) {
        if(isAuction){
            return auctions[id].tokenOwner != address(0);
        }
        return saleOrder[id].tokenOwner != address(0);
    }

    /**
     * @dev get current Dutch auction price 
     */

    function getPrice(uint auctionId) public dutchAuctionExists(auctionId) view returns(uint){
        uint endTime = dutchAuctions[auctionId].startAt + dutchAuctions[auctionId].duration;
        uint time = endTime > block.timestamp ? block.timestamp : endTime;
        uint discount = dutchAuctions[auctionId].discountRate * time;
        return dutchAuctions[auctionId].reservePrice - discount;
    }

    // TODO: consider reverting if the message sender is not WETH
    receive() external payable {}
    fallback() external payable {}
}