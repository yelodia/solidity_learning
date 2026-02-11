/*global describe, context, beforeEach, it, before, after*/
import { expect } from "chai";
import { network } from "hardhat";
import hre from "hardhat";
import StorageHelper from "../../helpers/StorageHelper.js";

const { ethers } = await network.connect();

describe("MimimiCatUSD", function () {
    let signers;
    let deployer;
    let mimimiCatUSD;
    let mockAggregator;
    let mockWETH;
    let helper;
    let snapshotId;

    const MINT_PRICE_USD = 100n * 10n ** 8n; // 100 USD, 8 decimals
    const AGGREGATOR_ETH_USD = 2000n * 10n ** 8n; // 2000 USD/ETH
    const MINT_PRICE_WEI = ethers.parseEther("0.05"); // 100e8 * 1e18 / 2000e8 = 0.05 ether
    const MAX_SUPPLY = 15;
    const WHITELIST_SUPPLY = 5;
    const BASE_URI = "ipfs://hidden_metadata";

    before(async function () {
        await hre.tasks.getTask("storage-layout").subtasks.get("export").run();
        snapshotId = await ethers.provider.send("evm_snapshot");
        signers = await ethers.getSigners();
        deployer = signers[0];
    });

    after(async function () {
        await ethers.provider.send("evm_revert", [snapshotId]);
    });

    const MULTISIG_ADDRESS = "0x0000000000000000000000000000000000000001";

    beforeEach(async function () {
        const MockAggregator = await ethers.getContractFactory("MockAggregatorV3");
        mockAggregator = await MockAggregator.deploy();
        await mockAggregator.setAnswer(Number(AGGREGATOR_ETH_USD));

        const MockWETHFactory = await ethers.getContractFactory("MockWETH");
        mockWETH = await MockWETHFactory.deploy();
        await mockWETH.deposit({ value: ethers.parseEther("1000") });

        const MimimiCatUSDFactory = await ethers.getContractFactory("MimimiCatUSD");
        mimimiCatUSD = await MimimiCatUSDFactory.deploy(
            MAX_SUPPLY,
            WHITELIST_SUPPLY,
            BASE_URI,
            MINT_PRICE_USD,
            MULTISIG_ADDRESS,
            await mockAggregator.getAddress(),
            await mockWETH.getAddress()
        );

        helper = new StorageHelper(
            "./storage_layout/contracts/homework_5/MimimiCatUSD.sol:MimimiCatUSD.json",
            mimimiCatUSD.target,
            ethers
        );
    });

    context("Initialization", function () {
        it("stores immutable aggregator and weth addresses", async function () {
            expect(await mimimiCatUSD.ethUsdAggregator()).to.equal(await mockAggregator.getAddress());
            expect(await mimimiCatUSD.weth()).to.equal(await mockWETH.getAddress());
            expect(await mimimiCatUSD.mintPrice()).to.equal(MINT_PRICE_USD);
            expect(await mimimiCatUSD.state()).to.equal(1);
        });
    });

    context("getMintPriceInWei", function () {
        it("returns wei from oracle price", async function () {
            expect(await mimimiCatUSD.getMintPriceInWei()).to.equal(MINT_PRICE_WEI);
        });
        it("updates when oracle price changes", async function () {
            await mockAggregator.setAnswer(Number(4000n * 10n ** 8n));
            expect(await mimimiCatUSD.getMintPriceInWei()).to.equal(ethers.parseEther("0.025"));
        });
    });

    context("mintUSD (WETH)", function () {
        beforeEach(async function () {
            await helper.setVariable("state", 2);
        });

        it("mints NFT to user and leaves native ETH on contract", async function () {
            const user = signers[10];
            await mockWETH.mint(user.address, MINT_PRICE_WEI);
            await mockWETH.connect(user).approve(await mimimiCatUSD.getAddress(), MINT_PRICE_WEI);

            const balanceBefore = await ethers.provider.getBalance(await mimimiCatUSD.getAddress());
            await mimimiCatUSD.connect(user).mintUSD();
            const balanceAfter = await ethers.provider.getBalance(await mimimiCatUSD.getAddress());

            expect(await mimimiCatUSD.ownerOf(1)).to.equal(user.address);
            expect(await mockWETH.balanceOf(await mimimiCatUSD.getAddress())).to.equal(0);
            expect(balanceAfter - balanceBefore).to.equal(MINT_PRICE_WEI);
        });

        it("reverts when allowance insufficient (WETH transferFrom reverts)", async function () {
            const user = signers[10];
            await mockWETH.mint(user.address, MINT_PRICE_WEI);
            // здесь мог бы быть MCTWETHTransferFailed, зависит от конкретной реализации transferFrom weth
            // в weth на сеполии есть require, до кастомной ошибки не доходит
            await expect(mimimiCatUSD.connect(user).mintUSD()).to.be.revert(ethers);
        });

        it("reverts when WETH balance insufficient (WETH transferFrom reverts)", async function () {
            const user = signers[10];
            await mockWETH.connect(user).approve(await mimimiCatUSD.getAddress(), MINT_PRICE_WEI);
            await expect(mimimiCatUSD.connect(user).mintUSD()).to.be.revert(ethers);
        });

    });
});
