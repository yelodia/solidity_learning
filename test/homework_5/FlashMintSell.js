/*global describe, beforeEach, it*/
import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("FlashMintSell", function () {
    let signers;
    let mimimiCat;
    let mockNftBuyer;
    let flashMintSell;
    let mockPool;
    let mockAddressesProvider;
    let mockWETH;
    let snapshotId;

    const MULTISIG_ADDRESS = "0x0000000000000000000000000000000000000001";
    const MINT_PRICE = ethers.parseEther("0.05");
    const BUY_PRICE = ethers.parseEther("0.051");
    const MAX_SUPPLY = 15;
    const WHITELIST_SUPPLY = 5;
    const BASE_URI = "ipfs://hidden_metadata";

    before(async function () {
        snapshotId = await ethers.provider.send("evm_snapshot");
        signers = await ethers.getSigners();
    });

    after(async function () {
        await ethers.provider.send("evm_revert", [snapshotId]);
    });

    beforeEach(async function () {
        const MimimiCatFactory = await ethers.getContractFactory("MimimiCat");
        mimimiCat = await MimimiCatFactory.deploy(
            MAX_SUPPLY,
            WHITELIST_SUPPLY,
            BASE_URI,
            MINT_PRICE,
            MULTISIG_ADDRESS
        );

        await mimimiCat.addModerators([signers[0].address]);
        await mimimiCat.setState(2); // STATE_OPEN

        const MockWETHFactory = await ethers.getContractFactory("MockWETH");
        mockWETH = await MockWETHFactory.deploy();
        await mockWETH.deposit({ value: ethers.parseEther("1000") });

        const MockNftBuyerFactory = await ethers.getContractFactory("MockNftBuyer");
        mockNftBuyer = await MockNftBuyerFactory.deploy(BUY_PRICE);
        await signers[0].sendTransaction({
            to: await mockNftBuyer.getAddress(),
            value: BUY_PRICE + ethers.parseEther("1"),
        });

        const MockPoolFactory = await ethers.getContractFactory("MockFlashLoanPool");
        mockPool = await MockPoolFactory.deploy(await mockWETH.getAddress());
        await mockWETH.mint(await mockPool.getAddress(), ethers.parseEther("1000"));

        const MockProviderFactory = await ethers.getContractFactory("MockPoolAddressesProvider");
        mockAddressesProvider = await MockProviderFactory.deploy(await mockPool.getAddress());

        const FlashMintSellFactory = await ethers.getContractFactory("FlashMintSell");
        flashMintSell = await FlashMintSellFactory.deploy(
            await mockWETH.getAddress(),
            await mockAddressesProvider.getAddress()
        );
    });

    async function requestMintAndSellDefault() {
        return requestMintAndSell(MINT_PRICE);
    }

    async function requestMintAndSell(amount) {
        const mintCalldata = mimimiCat.interface.encodeFunctionData("mint", []);
        const buySelector = mockNftBuyer.interface.getFunction("buy").selector;
        return flashMintSell.requestMintAndSell(
            await mimimiCat.getAddress(),
            await mockNftBuyer.getAddress(),
            amount,
            mintCalldata,
            buySelector
        );
    }

    it("NFT ends up in MockNftBuyer", async function () {
        await requestMintAndSellDefault();
        expect(await mimimiCat.ownerOf(1)).to.equal(await mockNftBuyer.getAddress());
    });

    it("pool is repaid", async function () {
        const poolBalanceBefore = await mockWETH.balanceOf(await mockPool.getAddress());
        await requestMintAndSellDefault();
        const poolBalanceAfter = await mockWETH.balanceOf(await mockPool.getAddress());
        expect(poolBalanceAfter).to.equal(poolBalanceBefore);
    });

    it("flash contract has no leftover WETH", async function () {
        await requestMintAndSellDefault();
        expect(await mockWETH.balanceOf(await flashMintSell.getAddress())).to.equal(0);
    });

    it("beneficiary receives arbitrage profit", async function () {
        const beneficiary = signers[1];
        const balanceBefore = await ethers.provider.getBalance(await beneficiary.getAddress());
        const tx = await flashMintSell.connect(beneficiary).requestMintAndSell(
            await mimimiCat.getAddress(),
            await mockNftBuyer.getAddress(),
            MINT_PRICE,
            mimimiCat.interface.encodeFunctionData("mint", []),
            mockNftBuyer.interface.getFunction("buy").selector
        );
        const receipt = await tx.wait();
        const gasPrice = receipt.gasPrice ?? receipt.maxFeePerGas ?? 0n;
        const gasCost = receipt.gasUsed * gasPrice;
        const balanceAfter = await ethers.provider.getBalance(await beneficiary.getAddress());
        const expectedProfit = BUY_PRICE - MINT_PRICE; // premium = 0
        expect(balanceAfter - balanceBefore).to.equal(expectedProfit - gasCost);
    });

    describe("negative cases", function () {
        it("reverts when mint fails (wrong amount)", async function () {
            const wrongAmount = MINT_PRICE - ethers.parseEther("0.01");
            await expect(
                flashMintSell.connect(signers[1]).requestMintAndSell(
                    await mimimiCat.getAddress(),
                    await mockNftBuyer.getAddress(),
                    wrongAmount,
                    mimimiCat.interface.encodeFunctionData("mint", []),
                    mockNftBuyer.interface.getFunction("buy").selector
                )
            ).to.be.revertedWithCustomError(flashMintSell, "MintFailed");
        });

        it("reverts when buy fails (buyer has no ETH)", async function () {
            await ethers.provider.send("hardhat_setBalance", [
                await mockNftBuyer.getAddress(),
                "0x0",
            ]);
            await expect(
                flashMintSell.connect(signers[1]).requestMintAndSell(
                    await mimimiCat.getAddress(),
                    await mockNftBuyer.getAddress(),
                    MINT_PRICE,
                    mimimiCat.interface.encodeFunctionData("mint", []),
                    mockNftBuyer.interface.getFunction("buy").selector
                )
            ).to.be.revertedWithCustomError(flashMintSell, "BuyFailed");
        });

        it("reverts when insufficient proceeds", async function () {
            await mockPool.setPremium(ethers.parseEther("0.001"));
            await mockNftBuyer.setBuyPrice(MINT_PRICE);
            await expect(
                flashMintSell.connect(signers[1]).requestMintAndSell(
                    await mimimiCat.getAddress(),
                    await mockNftBuyer.getAddress(),
                    MINT_PRICE,
                    mimimiCat.interface.encodeFunctionData("mint", []),
                    mockNftBuyer.interface.getFunction("buy").selector
                )
            ).to.be.revertedWith("FlashMintSell: insufficient proceeds");
        });
    });
});
