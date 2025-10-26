/*global describe, context, beforeEach, it*/
import { expect } from "chai";
import { network } from "hardhat";
import StorageHelper from "../../helpers/StorageHelper.js";
import hre from "hardhat";

const { ethers } = await network.connect();

describe("Somedata", function () {
    let signers;
    let contract;
    let helper;
    let snapshotId;

    before(async function () {
        snapshotId = await ethers.provider.send('evm_snapshot', []);
        await hre.tasks.getTask("storage-layout").subtasks.get('export').run();
    });

    after(async () => {
        await ethers.provider.send("evm_revert", [snapshotId]);
    });

    beforeEach(async function () {
        // Accounts
        signers = await ethers.getSigners();

        // Contracts
        const NativeBank = await ethers.getContractFactory("Somedata");
        contract = await NativeBank.deploy([signers[1].address, signers[2].address, signers[3].address]);

        helper = new StorageHelper(
            './storage_layout/contracts/experiments/Somedata.sol:Somedata.json',
            contract.target,
            ethers
        );
    });

    describe("Simple variables", function () {
        
        it("should set uint8 variable (lock)", async function () {
            await helper.setVariable('lock', 1);
            expect(await contract.lock()).to.equal(1);
        });
    
        it("should set address variable (owner)", async function () {
            await helper.setVariable('owner', signers[10].address);
            expect(await contract.owner()).to.equal(signers[10].address);
        });
    
        it("should set uint16 variable (commissionBp)", async function () {
            await helper.setVariable('commissionBp', 500);
            expect(await contract.commissionBp()).to.equal(500);
        });
    
        it("should set uint256 variable (accumulator)", async function () {
            const value = ethers.parseEther("100");
            await helper.setVariable('accumulator', value);
            expect(await contract.accumulator()).to.equal(value);
        });
    
        it("should set bytes32 variable (whiteList)", async function () {
            const hash = ethers.keccak256(ethers.toUtf8Bytes("test"));
            await helper.setVariable('whiteList', hash);
            expect(await contract.whiteList()).to.equal(hash);
        });
    
        it("should set uint32 variable (lolkek)", async function () {
            await helper.setVariable('lolkek', 12345);
            expect(await contract.lolkek()).to.equal(12345);
        });
    
        it("should set string variable (myname)", async function () {
            await helper.setVariable('myname', 'Alice');
            expect(await contract.myname()).to.equal('Alice');
        });
    });

    describe("Mappings", function () {
        it("should set mapping(address => uint256) - balanceOf", async function () {
            const balance = ethers.parseEther("50");
            await helper.setVariable('balanceOf', balance, signers[10].address);
            expect(await contract.balanceOf(signers[10].address)).to.equal(balance);
        });
    
        it("should set mapping(uint8 => address) - mapHolder", async function () {
            await helper.setVariable('mapHolder', signers[20].address, 5);
            expect(await contract.mapHolder(5)).to.equal(signers[20].address);
        });
    
        it("should set multiple mapping entries", async function () {
            const balance1 = ethers.parseEther("10");
            const balance2 = ethers.parseEther("20");
            
            await helper.setVariable('balanceOf', balance1, signers[10].address);
            await helper.setVariable('balanceOf', balance2, signers[20].address);
            
            expect(await contract.balanceOf(signers[10].address)).to.equal(balance1);
            expect(await contract.balanceOf(signers[20].address)).to.equal(balance2);
        });

        it("should set doubleMap", async function () {
            await helper.setVariable('doubleMap', true, [signers[10].address, signers[20].address]);
            expect(await contract.doubleMap(signers[10].address, signers[20].address)).to.be.true;
        });

        it("should set tripleMap", async function () {
            await helper.setVariable('tripleMap', 'hello', [signers[10].address, 5, true]);
            await helper.setVariable('tripleMap', 'world', [signers[10].address, 5, false]);
            await helper.setVariable('tripleMap', 'foo', [signers[10].address, 10, true]);
            
            expect(await contract.tripleMap(signers[10].address, 5, true)).to.equal('hello');
            expect(await contract.tripleMap(signers[10].address, 5, false)).to.equal('world');
            expect(await contract.tripleMap(signers[10].address, 10, true)).to.equal('foo');
        });

        it("should set quadMap", async function () {
            const [addr] = await ethers.getSigners();
            const hash1 = ethers.keccak256(ethers.toUtf8Bytes("test1"));
            const hash2 = ethers.keccak256(ethers.toUtf8Bytes("test2"));
            
            // mapping(address => mapping(uint => mapping(bool => mapping(bytes32 => uint))))
            await helper.setVariable('quadMap', 100, [signers[10].address, 5, true, hash1]);
            await helper.setVariable('quadMap', 200, [signers[10].address, 5, false, hash1]);
            await helper.setVariable('quadMap', 300, [signers[10].address, 10, true, hash2]);
            
            expect(await contract.quadMap(signers[10].address, 5, true, hash1)).to.equal(100n);
            expect(await contract.quadMap(signers[10].address, 5, false, hash1)).to.equal(200n);
            expect(await contract.quadMap(signers[10].address, 10, true, hash2)).to.equal(300n);
            
            // Проверяем несуществующую запись
            const emptyHash = ethers.ZeroHash;
            expect(await contract.quadMap(signers[10].address, 999, true, emptyHash)).to.equal(0n);
        });
    });

    describe("Arrays", function () {
        it("should set array length and elements", async function () {
            await helper.setArrayLength('stakeHolders', 3);
            await helper.setArrayElement('stakeHolders', 0, signers[20].address);
            await helper.setArrayElement('stakeHolders', 1, signers[21].address);
            await helper.setArrayElement('stakeHolders', 2, signers[22].address);
            
            expect(await contract.stakeHolders(0)).to.equal(signers[20].address);
            expect(await contract.stakeHolders(1)).to.equal(signers[21].address);
            expect(await contract.stakeHolders(2)).to.equal(signers[22].address);
        });
    
        it("should work with uint32 array", async function () {
            await helper.setArrayLength('numbers32', 2);
            await helper.setArrayElement('numbers32', 0, 100);
            await helper.setArrayElement('numbers32', 1, 200);
            
            expect(await contract.numbers32(0)).to.equal(100);
            expect(await contract.numbers32(1)).to.equal(200);
        });

        it("should work with uint8 array", async function () {
            await helper.setArrayLength('numbers8', 2);
            await helper.setArrayElement('numbers8', 0, 1);
            await helper.setArrayElement('numbers8', 1, 2);
            
            expect(await contract.numbers8(0)).to.equal(1);
            expect(await contract.numbers8(1)).to.equal(2);
        });

        it("should work with uint array", async function () {
            await helper.setArrayLength('numbers', 2);
            await helper.setArrayElement('numbers', 0, 156);
            await helper.setArrayElement('numbers', 1, 289);
            
            expect(await contract.numbers(0)).to.equal(156);
            expect(await contract.numbers(1)).to.equal(289);
        });

        it("should work with uint24 array", async function () {
            await helper.setArrayElement('numbers24', 0, 156);
            await helper.setArrayElement('numbers24', 1, 289);
            
            expect(await contract.numbers24(0)).to.equal(156);
            expect(await contract.numbers24(1)).to.equal(289);
        });

        it("should work with sstring array", async function () {
            await helper.setArrayElement('sstrings', 0, 'Alice');
            await helper.setArrayElement('sstrings', 1, 'Bob');
            
            expect(await contract.sstrings(0)).to.equal('Alice');
            expect(await contract.sstrings(1)).to.equal('Bob');
        });

        it("should work with dstring array", async function () {
            await helper.setArrayLength('dstrings', 2);
            await helper.setArrayElement('dstrings', 0, 'Alice');
            await helper.setArrayElement('dstrings', 1, 'Bob');
            
            expect(await contract.dstrings(0)).to.equal('Alice');
            expect(await contract.dstrings(1)).to.equal('Bob');
        });
    });

    describe("Packed storage", function () {
        it("should work with packed variables in same slot", async function () {
            // lock, owner, commissionBp - все в слоте 0
            await helper.setVariable('lock', 1);
            await helper.setVariable('owner', ethers.ZeroAddress);
            await helper.setVariable('commissionBp', 250);
            
            expect(await contract.lock()).to.equal(1);
            expect(await contract.owner()).to.equal(ethers.ZeroAddress);
            expect(await contract.commissionBp()).to.equal(250);
        });
    
        it("should modify one packed variable without affecting others", async function () {
            // Устанавливаем начальные значения
            await helper.setVariable('lock', 2);
            await helper.setVariable('commissionBp', 100);
            
            // Меняем только lock
            await helper.setVariable('lock', 5);
            
            expect(await contract.lock()).to.equal(5);
            expect(await contract.commissionBp()).to.equal(100); // не изменилось
        });
    });

});
