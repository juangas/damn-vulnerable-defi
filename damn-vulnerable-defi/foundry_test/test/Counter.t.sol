// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";

contract CounterTest is Test {
    Counter public counter;

    function setUp() public {
        counter = new Counter();
        counter.setNumber(0);
    }

    function testFuzz_Nonce(uint256 nonce) public {
        address result = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B,
                            nonce
                        )
                    )
                )
            )
        );
        assertNotEq(0x9B6fb606A9f5789444c17768c6dFCF2f83563801, result);
    }

    function test_Increment() public {
        counter.increment();
        assertEq(counter.number(), 1);
    }

    function testFuzz_SetNumber(uint256 x) public {
        counter.setNumber(x);
        assertEq(counter.number(), x);
    }
}
