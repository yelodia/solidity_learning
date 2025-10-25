/*global describe, context, beforeEach, it*/
import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

describe("NativeBankOpt", function () {
    let signers;
    let deployer;
    let contract;
    let attacker;
    let snapshotId;

    before(async function () {
        snapshotId = await ethers.provider.send('evm_snapshot');
    });

    after(async () => {
        await ethers.provider.send("evm_revert", [snapshotId]);
    });

    beforeEach(async function () {
        // Accounts
        signers = await ethers.getSigners();
        deployer = signers[0];

        // Contracts
        const NativeBank = await ethers.getContractFactory("NativeBank");
        contract = await NativeBank.deploy([signers[1].address, signers[2].address, signers[3].address]);
        
        const Attacker = await ethers.getContractFactory("ReentrancyAttacker");
        attacker = await Attacker.deploy(contract.target);
    });

    context("Initialization", async function () {
        it("Correctly constructs bank", async () => {
            expect(await contract.owner()).to.equal(deployer.address);
            expect(await contract.commissionBp()).to.equal(100);
            expect(await contract.stakeHolders(0)).to.equal(signers[1].address);
            expect(await contract.stakeHolders(1)).to.equal(signers[2].address);
            expect(await contract.stakeHolders(2)).to.equal(signers[3].address);
        });
    });

    context("Deposit", async function () {

        it("Insufficient Deposit", async () => {
            await expect(contract.connect(signers[5]).deposit({
                value: 10,
            })).to.be.revertedWithCustomError(contract, 'InsufficientDeposit');
        });

        it("Success Deposit", async () => {
            await contract.connect(signers[5]).deposit({
                value: ethers.parseEther("1.0"),
            });
            expect(await contract.balanceOf(signers[5].address)).to.equal(ethers.parseEther("0.99"));
            expect(await contract.accumulator()).to.equal(ethers.parseEther("0.01"));
            expect(await ethers.provider.getBalance(contract.target)).to.equal(ethers.parseEther("1.0"));

            await contract.connect(signers[5]).deposit({
                value: ethers.parseEther("0.5"),
            });
            expect(await contract.balanceOf(signers[5].address)).to.equal(ethers.parseEther("1.485"));
            expect(await contract.accumulator()).to.equal(ethers.parseEther("0.015"));
            expect(await ethers.provider.getBalance(contract.target)).to.equal(ethers.parseEther("1.5"));
        });

    });

    context("Set Comission", async function () {

        it("Set comission by owner", async () => {
            await contract.setCommission(150); // 1.5%
            expect(await contract.commissionBp()).to.equal(150);
        });

        it("Set comission not by owner", async () => {
            await expect(contract.connect(signers[7]).setCommission(150)).to.be.revertedWithCustomError(contract, 'NotContractOwner');
        });

        it("Set too large comission", async () => {
            await expect(contract.setCommission(5000)).to.be.revertedWith("don't be impudent");
        });

    });

    context("Withdraw", async function () {

        beforeEach(async function () {
            await contract.connect(signers[5]).deposit({
                value: ethers.parseEther("1.0")
            });
        });

        it("Success withdraw", async () => {
            await contract.connect(signers[5]).withdraw(ethers.parseEther("0.5"));
            expect(await contract.balanceOf(signers[5].address)).to.equal(ethers.parseEther("0.49"));

            await contract.connect(signers[5]).withdraw(ethers.parseEther("0.4"));
            expect(await contract.balanceOf(signers[5].address)).to.equal(ethers.parseEther("0.09"));
        });

        it("Zero withdraw", async () => {
            await expect(contract.connect(signers[5]).withdraw(0)).to.be.revertedWithCustomError(contract, 'WithdrawalAmountZero');
        });

        it("Exceeds Balance", async () => {
            await expect(contract.connect(signers[5]).withdraw(ethers.parseEther("1.5"))).to.be.revertedWithCustomError(contract, 'WithdrawalAmountExceedsBalance');
        });

    });

    context("Withdraw Accumulator", async function () {

        beforeEach(async function () {
            await contract.setCommission(2000);
            await contract.connect(signers[5]).deposit({
                value: ethers.parseEther("1.0")
            });
        });

        it("Withdraw not by owner", async () => {
            await expect(contract.connect(signers[5]).withdrawAccumulator(150)).to.be.revertedWithCustomError(contract, 'NotContractOwner');
        });

        it("Zero withdraw", async () => {
            await expect(contract.withdrawAccumulator(0)).to.be.revertedWithCustomError(contract, 'WithdrawalAmountZero');
        });

        it("Exceeds Balance", async () => {
            await expect(contract.withdrawAccumulator(ethers.parseEther("0.3"))).to.be.revertedWithCustomError(contract, 'WithdrawalAmountExceedsBalance');
        });

        it("Withdraw divided value", async () => {
            expect(await contract.accumulator()).to.equal(ethers.parseEther("0.2"));
            await contract.withdrawAccumulator(ethers.parseEther("0.1"));
            expect(await ethers.provider.getBalance(signers[1].address)).to.equal(ethers.parseEther("10000.025"));
            expect(await ethers.provider.getBalance(signers[2].address)).to.equal(ethers.parseEther("10000.025"));
            expect(await ethers.provider.getBalance(signers[3].address)).to.equal(ethers.parseEther("10000.025"));
            expect(await ethers.provider.getBalance(contract.target)).to.equal(ethers.parseEther("0.9"));
            expect(await contract.accumulator()).to.equal(ethers.parseEther("0.1"));
        });

        it("Withdraw non-divided value", async () => {
            let accumulator = ethers.parseEther("0.2") - 303n;
            let balance = ethers.parseEther("10000.025") + 75n;
            let contractBalance = ethers.parseEther("1.0") - 303n;

            await contract.withdrawAccumulator(303);
            expect(await ethers.provider.getBalance(signers[1].address)).to.equal(balance);
            expect(await ethers.provider.getBalance(signers[2].address)).to.equal(balance);
            expect(await ethers.provider.getBalance(signers[3].address)).to.equal(balance);
            expect(await ethers.provider.getBalance(contract.target)).to.equal(contractBalance);
            expect(await contract.accumulator()).to.equal(accumulator);
        });

        it("Withdraw too small", async () => {
            await expect(contract.withdrawAccumulator(3)).to.be.revertedWithCustomError(contract, 'WithdrawalAmountZero');
        });

    });

    context("Set Holders", async function () {

        it("Set holders by owner", async () => {
            await contract.setHolders([signers[17].address, signers[18].address, signers[19].address]);
            expect(await contract.stakeHolders(0)).to.equal(signers[17].address);
            expect(await contract.stakeHolders(1)).to.equal(signers[18].address);
            expect(await contract.stakeHolders(2)).to.equal(signers[19].address);
        });

        it("Set holders not by owner", async () => {
            await expect(contract.connect(signers[7]).setHolders([signers[17].address, signers[18].address, signers[19].address])).to.be.revertedWithCustomError(contract, 'NotContractOwner');
        });

    });

    context("Reentrancy", async function () {
        it("Revert", async () => {
            await expect(attacker.attack({value: ethers.parseEther("1.0")})).to.be.revert(ethers);
        });
    });
});