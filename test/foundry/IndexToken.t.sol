// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../../contracts/token/IndexToken.sol";

contract CounterTest is Test {
    IndexToken public indexToken;

    address feeReceiver = vm.addr(1);

    function setUp() public {
        indexToken = new IndexToken();
        indexToken.initialize(
            "Anti Inflation",
            "ANFI",
            1e18,
            feeReceiver,
            1000000e18
        );
    }

    function testIncrement() public {
        // counter.increment();
        assertEq(indexToken.owner(), address(this));
    }

    function testSetNumber(uint256 x) public {
        // counter.setNumber(x);
        // assertEq(counter.number(), x);
    }
}
