// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ShinoViNFT is ERC721, ERC721Burnable, ERC721URIStorage, Ownable {

    using Counters for Counters.Counter;
    
    struct Voucher {
        uint256 id;
        uint256 price;
        string uri;
        bytes signature;
    }

    // Mapping for minters
    mapping(uint256 => address) private minters;

    // Mapping for whitelist
    mapping(address => bool) private whitelist;

    // Token Counter
    Counters.Counter private _tokenIdCounter;

    // Royalties
    uint256 private royaltyFee;
    address private royaltyRecipient;
    uint256 platformFeeA;
    address platformRecipientA;
    uint256 platformFeeB;
    address platformRecipientB;

    constructor(
        string memory _name,
        string memory _symbol,
        address _owner,
        uint256 _royaltyFee,
        address _royaltyRecipient,
        uint256 _platformFeeA,
        address _platformRecipientA,
        uint256 _platformFeeB,
        address _platformRecipientB
    ) ERC721(_name, _symbol) {
        require(_royaltyFee <= 10000, "Max royalty is 10 percent");
        require(_royaltyRecipient != address(0), "Royalty recipient null");
        royaltyFee = _royaltyFee;
        royaltyRecipient = _royaltyRecipient;
        platformFeeA = _platformFeeA;
        platformRecipientA = _platformRecipientA;
        platformFeeB = _platformFeeB;
        platformRecipientB = _platformRecipientB;
        transferOwnership(_owner);
        whitelist[msg.sender] = true;
    }

    function safeMint(address to, string memory uri) public onlyOwner {
        require(to != address(0), "To address null");
        require(whitelist[msg.sender] == true, "Not whitelisted");
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        minters[tokenId] = to;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function lazyMint(address to, string memory uri, Voucher calldata voucher) public payable {
        require(to != address(0), "To address null");
        require(_verify(voucher) == true);
        require(msg.value >= voucher.price, "Mint price not met");

        uint256 _platformFeeA = (voucher.price * platformFeeA) / 10000;
        uint256 _platformFeeB = (voucher.price * platformFeeB) / 10000;
        uint256 totalAmount = msg.value;

        payable(platformRecipientA).transfer(
            _platformFeeA
        );
        totalAmount -= _platformFeeA;

        payable(platformRecipientB).transfer(
            _platformFeeB
        );
        totalAmount -= _platformFeeB;

        // Finally pay creator remainder and transfer NFT to minter.
        payable(owner()).transfer(totalAmount);

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        minters[tokenId] = to;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function _verify(Voucher calldata voucher) internal view returns (bool) {
        bytes32 digest = keccak256(abi.encodePacked(voucher.id, voucher.price, voucher.uri));

        address _sig = ECDSA.recover(ECDSA.toEthSignedMessageHash(digest), voucher.signature);
        if (_sig == owner()) {
            return true;
        } else {
            return false;
        }
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function getRoyaltyFee() external view returns (uint256) {
        return royaltyFee;
    }

    function getRoyaltyRecipient() external view returns(address) {
        return royaltyRecipient;
    }

    function isMinter(uint256 tokenId) external view returns(address)  {
        return address(minters[tokenId]);
    }

    function updateRoyaltyFee(uint256 _royaltyFee) external onlyOwner {
        require(_royaltyFee <= 10000, "can't more than 10 percent");
        royaltyFee = _royaltyFee;
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

}

