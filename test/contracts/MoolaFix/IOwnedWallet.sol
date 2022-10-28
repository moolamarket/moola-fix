// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

interface IOwnedWallet {
  function executeMany(address payable[] calldata to, uint[] calldata value, bytes[] calldata data)
      external returns (bytes memory result);
}