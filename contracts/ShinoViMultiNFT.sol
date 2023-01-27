// SPDX-License-Identifier: MIT
// Author: Cormac Guerin
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract ShinoViMultiNFT is ERC1155, Ownable {

    string name;
    string symbol;
    // Royalties
    uint256 private royaltyFee;
    address private royaltyRecipient;
    uint256 platformFeeA;
    address platformRecipientA;
    uint256 platformFeeB;
    address platformRecipientB;

    mapping (uint256 => uint256) public tokenSupply;

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
    ) ERC1155("") {
        require(_royaltyFee <= 10000, "Max royalty is 10 percent");
        require(_royaltyRecipient != address(0), "Royalty recipient null");
        name = _name;
        symbol = _symbol;
        royaltyFee = _royaltyFee;
        royaltyRecipient = _royaltyRecipient;
        platformFeeA = _platformFeeA;
        platformRecipientA = _platformRecipientA;
        platformFeeB = _platformFeeB;
        platformRecipientB = _platformRecipientB;
        transferOwnership(_owner);
    }

    function totalSupply(
      uint256 _id
    ) public view returns (uint256) {
      return tokenSupply[_id];
    }

    function mint(
      address _to,
      uint256 _id,
      uint256 _quantity,
      bytes memory _data
    ) public {
      _mint(_to, _id, _quantity, _data);
      //tokenSupply[_id] = tokenSupply[_id].add(_quantity);
    }

}
