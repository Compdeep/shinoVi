// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "./ShinoViMultiNFT.sol";

contract ShinoViMultiNFTFactory {

    address owner;
    address platform;

    //constructor(address _platform) {
    constructor() {
      owner = msg.sender;
    //  platform = _platform;
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

        // require(platform == msg.sender, "access denied");

        ShinoViMultiNFT shinoViMultiNFT = new ShinoViMultiNFT(
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

        return address(shinoViMultiNFT);

    }

    /*
    function setPlatform(address _address) external returns (bool) {
      require(owner == msg.sender, "access denied");
      platform = _address;
      return true;
    }
    */

}

