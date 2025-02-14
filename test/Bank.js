/*global describe, context, beforeEach, it*/
const { ethers } = require("hardhat");
const { expect } = require("chai");

describe("NativeBank", function () {
    let signers;
    let deployer;
    let contract;
    let attacker;

    beforeEach(async function () {
        // Accounts
        signers = await ethers.getSigners();
        deployer = signers[0];

        // Contracts
        const Bank = await ethers.getContractFactory("Bank");
        contract = await Bank.deploy();
        await contract.deployed();
        
        const Attacker = await ethers.getContractFactory("Attacker");
        attacker = await Attacker.deploy(contract.address);
        await attacker.deployed();
    });

    context("Reentrancy", async function () {
        it("Revert", async () => {
            //await attacker.attack({value: ethers.utils.parseEther("1.0")});
            await expect(attacker.attack({value: ethers.utils.parseEther("1.0")})).to.be.revertedWithCustomError(contract, 'ReetrancyAttack');
        });
    });
});