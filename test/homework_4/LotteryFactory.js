/*global describe, context, beforeEach, it*/
const { ethers, network } = require("hardhat");
const { expect } = require("chai");

describe("LotteryFactory", function () {
    let signers;
    let deployer;
    let contract1;
    let contract0;
    let multiWallet;
    let factory;
    let snapshotId;

    // start tests
    before(async function () {
        snapshotId = await network.provider.send('evm_snapshot');
        signers = await ethers.getSigners();
    });

    after(async () => {
        await network.provider.send("evm_revert", [snapshotId]);
    });

    beforeEach(async function () {
        // Accounts
        deployer = signers[0];

        // Contracts
        const MultiSigWallet = await ethers.getContractFactory("MultiSigWallet");
        multiWallet = await MultiSigWallet.deploy(signers.slice(0,11).map(function(em){return em.address}), 5);
        await multiWallet.deployed();

        const LotteryFactory = await ethers.getContractFactory("LotteryFactory");
        factory = await LotteryFactory.deploy();
        await factory.deployed();

        await factory.connect(signers[1]).createItem(500, "ipfs://hidden_puppies/", ethers.utils.parseEther("0.05"), multiWallet.address, "PrettyPuppies", "PTP");
        await factory.connect(signers[2]).createItem(100, "ipfs://hidden_metadata/", ethers.utils.parseEther("0.01"), multiWallet.address, "AngryBirds", "AGB");
        let proxies = await factory.getItems();

        contract0 = await ethers.getContractAt("LotteryCloneable", proxies[0]);
        contract1 = await ethers.getContractAt("LotteryCloneable", proxies[1]);
    });

    context("Initialization", async function () {
        it("Correctly constructs clones with different storages", async () => {
            expect(await contract0.owner()).to.equal(signers[1].address);
            expect(await contract0.maxSupply()).to.equal(5000);
            expect(await contract0.mintPrice()).to.equal(ethers.utils.parseEther("0.05"));
            expect(await contract0.name()).to.equal("PrettyPuppies");
            expect(await contract0.symbol()).to.equal("PTP");
            expect(await contract0.state()).to.equal(1);

            expect(await contract1.owner()).to.equal(signers[2].address);
            expect(await contract1.maxSupply()).to.equal(5000);
            expect(await contract1.mintPrice()).to.equal(ethers.utils.parseEther("0.01"));
            expect(await contract1.name()).to.equal("AngryBirds");
            expect(await contract1.symbol()).to.equal("AGB");
            expect(await contract1.state()).to.equal(1);
        });

        it("re-initialisation is disabled", async function () {
            await expect(contract0.initialize(10, "ipfs://new_metadata/", ethers.utils.parseEther("0.5"), multiWallet.address, "NewName", "NNN", signers[0].address)).to.be.reverted;
            await expect(contract1.initialize(10, "ipfs://new_metadata/", ethers.utils.parseEther("0.5"), multiWallet.address, "NewName", "NNN", signers[0].address)).to.be.reverted;
        });
    });
   
});