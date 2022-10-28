// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import '@ganache/console.log/console.sol';

contract ConsoleLogTest {
  constructor() public {
    console.log('================== Here we go ==================');
  }

  function testCall() public {
    console.log('================== Here we go in call ==================');
  }
}
