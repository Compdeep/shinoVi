// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface IShinoViPlatform {

    struct PlatformFee {
        address recipientA;
        uint256 feeA;
        address recipientB;
        uint256 feeB;
    }

    function getDefaultFees() external returns (PlatformFee memory);

    function getCustomFees(address _address) external returns (PlatformFee memory);

    function isShinoViAdmin() external view returns (bool);

    function isShinoViNFT(address _nft) external view returns (bool);

    function getPlatformFees(address _nft, uint256 _tokenId, address _seller) external returns (PlatformFee memory);

    function getRoyaltyFee(address _nft) external returns (uint256);

    function getRoyaltyRecipient(address _nft) external returns (address);

    function processTransaction(Transaction memory t) external;

    function safeTransferFrom(address _nft, address _from, address _to, uint256 _tokenId, uint256 _amount) external;

}

struct Auction {
    address nft;
    uint256 tokenId;
    uint256 amount;
    address creator;
    address payableToken;
    uint256 initialPrice;
    uint256 minBid;
    uint256 startTime;
    uint256 endTime;
    uint256 bidPrice;
    address winningBidder;
    bool success;
}

struct Listing {
    address nft;
    uint256 tokenId;
    uint256 amount;
    address owner;
    uint256 price;
    uint256 chainId;
    address payableToken;
    bool sold;
}

struct Offer {
    address nft;
    uint256 tokenId;
    uint256 amount;
    address offerer;
    uint256 offerPrice;
    address payableToken;
    bool accepted;
}

struct Transaction {
    address nft;
    uint256 tokenId;
    uint256 amount;
    uint256 price;
    address payableToken;
    address seller;
    address buyer;
    bool transferFrom;
}

contract ShinoViMarketplace is Initializable, ReentrancyGuardUpgradeable  {

    event ListedNFT(
        address indexed nft,
        uint256 indexed tokenId,
        uint256 amount,
        address payableToken,
        uint256 price,
        address indexed owner
    );

    event SoldNFT(
        address indexed nft,
        uint256 indexed tokenId,
        uint256 amount,
        address payableToken,
        uint256 price,
        address owner,
        address indexed buyer
    );

    event OfferredNFT(
        address indexed nft,
        uint256 indexed tokenId,
        uint256 amount,
        address payableToken,
        uint256 offerPrice,
        address indexed offerer
    );

    event CanceledOffer(
        address indexed nft,
        uint256 indexed tokenId,
        uint256 amount,
        address payableToken,
        uint256 offerPrice,
        address indexed offerer
    );

    event AcceptedOffer(
        address indexed nft,
        uint256 indexed tokenId,
        uint256 amount,
        address payableToken,
        uint256 offerPrice,
        address offerer,
        address indexed nftOwner
    );

    event CreatedAuction(
        address indexed nft,
        uint256 indexed tokenId,
        uint256 amount,
        address payableToken,
        uint256 price,
        uint256 minBid,
        uint256 startTime,
        uint256 endTime,
        address indexed creator
    );

    event PlacedBid(
        address indexed nft,
        uint256 indexed tokenId,
        uint256 amount,
        address payableToken,
        uint256 bidPrice,
        address indexed bidder
    );

    event AuctionResult(
        address indexed nft,
        uint256 indexed tokenId,
        uint256 amount,
        address creator,
        address indexed winner,
        uint256 price,
        address caller
    );


    // token => isPayable
    mapping(address => bool) private payableTokens;
    // nft => tokenId => listing 
    mapping(address => mapping(uint256 => Listing)) private listings;
    // nft => tokenId => auction 
    mapping(address => mapping(uint256 => Auction)) private auctions;
    // nft => tokenId => offer array
    mapping(address => mapping(uint256 => Offer[])) private offers;


    IShinoViPlatform private shinoViPlatform;
    function initialize(address _shinoViPlatform) public initializer {
        shinoViPlatform = IShinoViPlatform(_shinoViPlatform);
    }

   /*
    IShinoViPlatform private immutable shinoViPlatform;

    constructor(
      IShinoViPlatform _shinoViPlatform
    ) {
      shinoViPlatform = _shinoViPlatform;
    }
   */

    modifier isAdmin() {
        require(shinoViPlatform.isShinoViAdmin() == true, "access denied");
        _;
    }

    modifier isShinoViNFT(address _nft) {
        require(shinoViPlatform.isShinoViNFT(_nft) == true, "unrecognized NFT collection");
        _;
    }

    modifier isListed(address _nft, uint256 _tokenId) {
        require(
             listings[_nft][_tokenId].owner != address(0) &&  listings[_nft][_tokenId].sold == false,
            "not listed"
        );
        _;
    }

    modifier isPayableToken(address _payableToken) {
        require(
            _payableToken != address(0) && payableTokens[_payableToken],
            "invalid pay token"
        );
        _;
    }

    modifier isAuction(address _nft, uint256 _tokenId) {
        require(
            auctions[_nft][_tokenId].nft != address(0) && auctions[_nft][_tokenId].success == false,
            "auction already created"
        );
        _;
    }

    modifier isNotAuction(address _nft, uint256 _tokenId) {
        require(
            auctions[_nft][_tokenId].nft == address(0) || auctions[_nft][_tokenId].success,
            "auction already created"
        );
        _;
    }

    modifier isOfferred(
        address _nft,
        uint256 _tokenId,
        address _offerer,
        uint256 _index
    ) {
        require(
            offers[_nft][_tokenId][_index].offerPrice > 0 && offers[_nft][_tokenId][_index].offerer != address(0),
            "not on offer"
        );
        _;
    }

    function listNFT(
        address _nft,
        uint256 _tokenId,
        uint256 _amount,
        uint256 _price,
        uint256 _chainId,
        address _payableToken)
        external
        isShinoViNFT(_nft)
        isPayableToken(_payableToken)
        nonReentrant
    {

        require(_amount > 0, "access denied");

        shinoViPlatform.safeTransferFrom(_nft, msg.sender, address(this), _tokenId, _amount);

        listings[_nft][_tokenId] = Listing({
            nft: _nft,
            tokenId: _tokenId,
            amount: _amount,
            owner: msg.sender,
            price: _price,
            chainId: _chainId,
            payableToken: _payableToken,
            sold: false
        });

        emit ListedNFT(_nft, _tokenId, _amount, _payableToken, _price, msg.sender);

    }

    // delist the nft
    function deListing(address _nft, uint256 _tokenId)
        external
        isListed(_nft, _tokenId)
        nonReentrant
    {

        Listing memory thisNFT = listings[_nft][_tokenId];
        require(thisNFT.owner == msg.sender, "access denied");
        require(thisNFT.sold == false, "nft has already been sold");

        delete listings[_nft][_tokenId];
        // IERC721(_nft).transferFrom(address(this), msg.sender, _tokenId);
        shinoViPlatform.safeTransferFrom(_nft, address(this), msg.sender, _tokenId, thisNFT.amount);

    }

    // purchase listing
    function purchaseNFT(
        address _nft,
        uint256 _tokenId,
        uint256 _amount,
        address _payableToken,
        uint256 _price)
        external
        isListed(_nft, _tokenId)
        nonReentrant
    {
        Listing storage thisNFT = listings[_nft][_tokenId];
        require(
            _payableToken != address(0) && _payableToken == thisNFT.payableToken,
            "invalid pay token"
        );
        require(thisNFT.sold == false, "nft has already been sold");
        require(_price >= thisNFT.price, "invalid price");
        thisNFT.sold = true; 

        Transaction memory t = Transaction({
            nft: _nft,
            tokenId: _tokenId,
            amount: _amount,
            price: _price,
            payableToken: _payableToken,
            seller: thisNFT.owner,
            buyer: msg.sender,
            transferFrom: true
        });
        shinoViPlatform.processTransaction(t);

        emit SoldNFT(
            thisNFT.nft,
            thisNFT.tokenId,
            thisNFT.amount,
            thisNFT.payableToken,
            _price,
            thisNFT.owner,
            msg.sender
        );

    }

    function createOffer(
        address _nft,
        uint256 _tokenId,
        uint256 _amount,
        address _payableToken,
        uint256 _offerPrice
    ) external
        isListed(_nft, _tokenId)
        nonReentrant
    {
        require(_offerPrice > 0, "price must be greater than zero.");

        Listing memory nft = listings[_nft][_tokenId];

        IERC20(nft.payableToken).transferFrom(
            msg.sender,
            address(this),
            _offerPrice
        );

        offers[_nft][_tokenId].push(Offer({
            nft: _nft,
            tokenId: _tokenId,
            amount: _amount,
            offerer: msg.sender,
            payableToken: _payableToken,
            offerPrice: _offerPrice,
            accepted: false
        }));

        emit OfferredNFT(
            _nft,
            _tokenId,
            _amount,
            _payableToken,
            _offerPrice,
            msg.sender
        );

    }

    function cancelOffer(address _nft, uint256 _tokenId, uint _index)
        external
        isOfferred(_nft, _tokenId, msg.sender, _index)
        nonReentrant
    {
        Offer memory offer = offers[_nft][_tokenId][_index];
        require(offer.offerer == msg.sender, "not offerer");
        require(offer.accepted == false, "offer already accepted");
        delete offers[_nft][_tokenId][_index];
        IERC20(offer.payableToken).transfer(offer.offerer, offer.offerPrice);
        
        emit CanceledOffer(
            offer.nft,
            offer.tokenId,
            offer.amount,
            offer.payableToken,
            offer.offerPrice,
            msg.sender
        );
       
    }

    function acceptOffer(
        address _nft,
        uint256 _tokenId,
        uint256 _amount,
        address _offerer,
        uint256 _index
    )
        external
        isOfferred(_nft, _tokenId, _offerer, _index)
        isListed(_nft, _tokenId)
        nonReentrant
    {
        require(
            listings[_nft][_tokenId].owner == msg.sender,
            "not listed owner"
        );
        Offer storage offer = offers[_nft][_tokenId][_index];
        Listing storage list = listings[offer.nft][offer.tokenId];
        require(list.sold == false, "item already sold");
        require(offer.accepted == false, "offer already accepted");

        list.sold = true;
        offer.accepted = true;

        Transaction memory t = Transaction({
            nft: _nft,
            tokenId: _tokenId,
            amount: _amount,
            price: offer.offerPrice,
            payableToken: offer.payableToken,
            seller: msg.sender,
            buyer: offer.offerer,
            transferFrom: false
        });
        shinoViPlatform.processTransaction(t);

        emit AcceptedOffer(
            offer.nft,
            offer.tokenId,
            offer.amount,
            offer.payableToken,
            offer.offerPrice,
            offer.offerer,
            list.owner
        );
       
    }

    //
    function createAuction(
        address _nft,
        uint256 _tokenId,
        uint256 _amount,
        address _payableToken,
        uint256 _price,
        uint256 _minBid,
        uint256 _startTime,
        uint256 _endTime)
        external isPayableToken(_payableToken)
        isNotAuction(_nft, _tokenId)
        nonReentrant
    {
        //IERC721 nft = IERC721(_nft);
        //require(nft.ownerOf(_tokenId) == msg.sender, "not nft owner");
        require(_endTime > _startTime, "invalid end time");

        // nft.transferFrom(msg.sender, address(this), _tokenId);
        shinoViPlatform.safeTransferFrom(_nft, msg.sender, address(this), _tokenId, _amount);

        auctions[_nft][_tokenId] = Auction({
            nft: _nft,
            tokenId: _tokenId,
            amount: _amount,
            creator: msg.sender,
            payableToken: _payableToken,
            initialPrice: _price,
            minBid: _minBid,
            startTime: _startTime,
            endTime: _endTime,
            winningBidder: address(0),
            bidPrice: _price,
            success: false
        });

        emit CreatedAuction(
            _nft,
            _tokenId,
            _amount,
            _payableToken,
            _price,
            _minBid,
            _startTime,
            _endTime,
            msg.sender
        );
       
    }

    // this function is dangerous,
    function cancelAuction(address _nft, uint256 _tokenId)
        external
        isAuction(_nft, _tokenId)
        nonReentrant
    {
        Auction memory auction = auctions[_nft][_tokenId];
        require(auction.creator == msg.sender, "not auction creator");
        require(block.timestamp < auction.startTime, "auction already started");
        require(auction.winningBidder == address(0), "already have bidder");

        delete auctions[_nft][_tokenId];
        //IERC721 nft = IERC721(_nft);
        //nft.transferFrom(address(this), msg.sender, _tokenId);
        shinoViPlatform.safeTransferFrom(_nft, address(this), msg.sender, _tokenId, auction.amount);
    }

    function placeBid(
        address _nft,
        uint256 _tokenId,
        uint256 _bidPrice
    ) external
        isAuction(_nft, _tokenId)
        nonReentrant
    {
        require(
            block.timestamp >= auctions[_nft][_tokenId].startTime,
            "auction not started"
        );
        require(
            block.timestamp <= auctions[_nft][_tokenId].endTime,
            "auction has ended"
        );
        require(
            _bidPrice >=
                 auctions[_nft][_tokenId].minBid,
            "bid price less than minimum"
        );
        require(
            _bidPrice >
                auctions[_nft][_tokenId].bidPrice,
            "bid price less than current"
        );
        Auction storage auction = auctions[_nft][_tokenId];
        IERC20 payableToken = IERC20(auction.payableToken);
        payableToken.transferFrom(msg.sender, address(this), _bidPrice);

        if (auction.winningBidder != address(0)) {
            address previousBidder = auction.winningBidder;
            uint256 previousBidPrice = auction.bidPrice;

            // Set new winning bid 
            auction.winningBidder = msg.sender;
            auction.bidPrice = _bidPrice;

            // Return funds to previous bidder
            payableToken.transfer(previousBidder, previousBidPrice);
        }

        emit PlacedBid(_nft, _tokenId, auction.amount, auction.payableToken, _bidPrice, msg.sender);
    }

    function finalizeAuction(address _nft, uint256 _tokenId)
        external
        nonReentrant
    {

        Auction storage auction = auctions[_nft][_tokenId];
        require(auction.success == false, "auction already finished");
        require(
        //    msg.sender == owner ||
                msg.sender == auction.creator ||
                msg.sender == auction.winningBidder,
            "access denied"
        );
        require(
            block.timestamp > auction.endTime,
            "auction still in progress"
        );

        auction.success = true;

        Transaction memory t = Transaction({
            nft: _nft,
            tokenId: _tokenId,
            amount: auction.amount,
            price: auction.bidPrice,
            payableToken: auction.payableToken,
            seller: auction.creator,
            buyer: auction.winningBidder,
            transferFrom: false
        });
        shinoViPlatform.processTransaction(t);

        emit AuctionResult(
            _nft,
            _tokenId,
            auction.amount,
            auction.creator,
            auction.winningBidder,
            auction.bidPrice,
            msg.sender
        );

    }

    /*
    function processTransaction(Transaction memory t) private {

        uint256 totalAmount = t.price;
        address royaltyRecipient = shinoViPlatform.getRoyaltyRecipient(t.nft);
        uint256 royaltyFee = shinoViPlatform.getRoyaltyFee(t.nft);

        if (royaltyFee > 0) {

            uint256 royaltyAmount = (t.price * royaltyFee) / 10000;

            // Process royalty
            if (t.transferFrom == true) {

                IERC20(t.payableToken).transferFrom(
                    t.buyer,
                    royaltyRecipient,
                    royaltyAmount
                );

            } else {

                IERC20(t.payableToken).transfer(
                    royaltyRecipient,
                    royaltyAmount
                );

            }
            totalAmount -= royaltyAmount;

        }

        IShinoViPlatform.PlatformFee memory platformFees = shinoViPlatform.getPlatformFees(t.nft, t.tokenId, t.seller);

        // process platform fees

        uint256 platformFeeA = (t.price * platformFees.feeA) / 10000;
        uint256 platformFeeB = (t.price * platformFees.feeB) / 10000;

        if (t.transferFrom == true) {

            IERC20(t.payableToken).transferFrom(
                t.buyer,
                platformFees.recipientA,
                platformFeeA
            );
            totalAmount -= platformFeeA;

            IERC20(t.payableToken).transferFrom(
                t.buyer,
                platformFees.recipientB,
                platformFeeB
            );
            totalAmount -= platformFeeB;

            // pay seller
            IERC20(t.payableToken).transferFrom(
                t.buyer,
                t.seller,
                totalAmount
            );

            // finally transfer NFT
            safeTransferFrom(t.nft, t.seller, t.buyer, t.tokenId, t.amount);

        } else {

            IERC20(t.payableToken).transfer(
                platformFees.recipientA,
                platformFeeA
            );
            totalAmount -= platformFeeA;

            IERC20(t.payableToken).transfer(
                platformFees.recipientB,
                platformFeeB
            );
            totalAmount -= platformFeeB;

            // pay seller
            IERC20(t.payableToken).transfer(
                t.seller,
                totalAmount
            );

            // finally transfer NFT
            safeTransferFrom(t.nft, address(this), t.buyer, t.tokenId, t.amount);

        }

    }

    function safeTransferFrom(address _nft, address _from, address _to, uint256 _tokenId, uint256 _amount) internal {

        if (IERC165(_nft).supportsInterface(type(IERC721).interfaceId)) {

            IERC721 nft = IERC721(_nft);
            require(_amount == 1, "amount must be one");
            require(nft.ownerOf(_tokenId) == _from, "access denied");
            nft.transferFrom(_from, _to, _tokenId);

        } else if (IERC165(_nft).supportsInterface(type(IERC1155).interfaceId)) {

            IERC1155 nft = IERC1155(_nft);
            require(_amount > 0, "amount must be positive");
            require(nft.balanceOf(_from, _tokenId) >= _amount, "access denied");
            nft.safeTransferFrom(_from, _to, _tokenId, _amount, "");

        } else {

            revert();

        }

    }
    */

    function getListedNFT(address _nft, uint256 _tokenId)
        external
        view
        returns (Listing memory)
    {
        return listings[_nft][_tokenId];
    }

    function setPayableToken(address _token, bool _enable) external isAdmin {
        require(_token != address(0), "invalid token");
        payableTokens[_token] = _enable;
    }

}

