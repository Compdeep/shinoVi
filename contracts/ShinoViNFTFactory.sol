// SPDX-License-Identifier: MIT
// Author: Cormac Guerin
pragma solidity ^0.8.4;

import "./ShinoViNFT.sol";

contract ShinoViNFTFactory {

    address platform;
    address owner;

    constructor() {
      owner = msg.sender;
    }

    function create(
      string memory _name,
      string memory _symbol,
      address _owner,
      uint256 _royaltyFee,
      address _royaltyRecipient,
      uint256 _platformFeeA,
      address _platformRecipientA,
      uint256 _platformFeeB,
      address _platformRecipientB) external returns (address) {

        ShinoViNFT shinoViNFT = new ShinoViNFT(
          _name,
          _symbol,
          _owner,
          _royaltyFee,
          _royaltyRecipient,
          _platformFeeA,
          _platformRecipientA,
          _platformFeeB,
          _platformRecipientB
        );

        return address(shinoViNFT);

    }

}

