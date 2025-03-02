/*global describe, context, beforeEach, it*/
const { ethers, network } = require("hardhat");
const { expect } = require("chai");
const {MerkleTree} = require('merkletreejs');
const keccak256 = require('keccak256');

describe("MimimmiCatUp", function () {
    let signers;
    let deployer;
    let contract;
    let multiWallet;
    let proxy;
    let implementation;
    let implementationV2;
    let snapshotId;

    let abiFunc = ["function initialize(uint32 _whiteListSupply, string _uri, uint256 _mintPrice, address _signer)", "function setWhiteList(bytes32 _whiteList)"];
    let iface = new ethers.utils.Interface(abiFunc);
    let initAbi;
    let whitelistAbi;
    let merkleTree;
    let merkleRoot;

    // helpers

    function _proof(signer) {
        return merkleTree.getHexProof(keccak256(signer.address));
    }

    async function _signForClose() {
        let domain = await contract.domainSeparator();
        let messageHash = ethers.utils.solidityKeccak256(['bytes32', 'string'], [domain, 'ipfs://awesome_collection/']);
        let sign = await deployer.signMessage(ethers.utils.arrayify(messageHash));
	    return ethers.utils.splitSignature(sign);
    }

    function _domain(version) {
        return {
            name: "MimimiCat",
            version: version,
            chainId: 31337,
            verifyingContract: contract.address
        }
    }

    async function _signForMint(signer, version) {
        const types = {
            Mint: [
              { name: "owner", type: "address" },
              { name: "nonce", type: "uint256" },
            ],
        };
        let nonce = await contract.nonces(signer.address);
        const message = {
            owner: signer.address,
            nonce: nonce,
        };
        const signature = await signer._signTypedData(_domain(version), types, message);
	    return ethers.utils.splitSignature(signature);
    }

    // start tests
    before(async function () {
        snapshotId = await network.provider.send('evm_snapshot');
        signers = await ethers.getSigners();

        var leafNodes = signers.slice(51,56).map(signer => keccak256(signer.address));
        merkleTree = new MerkleTree(leafNodes, keccak256, {sortPairs: true});
        merkleRoot = '0x'+merkleTree.getRoot().toString('hex');
        whitelistAbi = iface.encodeFunctionData('setWhiteList', [merkleRoot]);
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
        
        initAbi = iface.encodeFunctionData('initialize', [5, "ipfs://hidden_metadata/", ethers.utils.parseEther("0.05"), multiWallet.address]);

        const MimimiCat = await ethers.getContractFactory("MimimiCatUp");
        implementation = await MimimiCat.deploy(15);
        await implementation.deployed();

        const MimimiCatV2 = await ethers.getContractFactory("MimimiCatUpV2");
        implementationV2 = await MimimiCatV2.deploy(15);
        await implementationV2.deployed();

        const MimimiCatProxy = await ethers.getContractFactory("MimimiCatProxy");
        proxy = await MimimiCatProxy.deploy(implementation.address, initAbi);
        await proxy.deployed();

        contract = await ethers.getContractAt("MimimiCatUp", proxy.address);

        await contract.addStakeHolders([signers[0].address, signers[1].address]);
        await contract.addModerators([signers[8].address, signers[9].address, signers[10].address]);

        await multiWallet.submitTransaction(contract.address, 0, whitelistAbi);

        for(var i=1; i<6; i++) {
            await multiWallet.connect(signers[i]).confirmTransaction(0);
        }
    });

    context("Initialization", async function () {
        it("Correctly constructs nft", async () => {
            expect(await contract.owner()).to.equal(deployer.address);
            expect(await contract.maxSupply()).to.equal(15);
            expect(await contract.mintPrice()).to.equal(ethers.utils.parseEther("0.05"));
            expect(await contract.name()).to.equal("MimimiCat");
            expect(await contract.state()).to.equal(1);
            expect(await proxy.getImplementation()).to.equal(implementation.address);
        });

        it("re-initialisation is disabled", async function () {
            await expect(contract.initialize(10, "ipfs://new_metadata/", ethers.utils.parseEther("0.05"), multiWallet.address)).to.be.reverted;
        });
    });

    context("Access control works correctly", async function () {
        it("non-stakeholder cannot set mint price", async () => {
            await expect(contract.connect(signers[5]).setMintPrice(ethers.utils.parseEther("0.1"))).to.be.revertedWithCustomError(contract, 'AccessControlUnauthorizedAccount');
        });
    
        it("stakeholder can set mint price", async () => {
            await contract.connect(signers[1]).setMintPrice(ethers.utils.parseEther("0.1"));
            expect(await contract.mintPrice()).to.equal(ethers.utils.parseEther("0.1"));
        });

        it("non-multiwallet cannot set white list", async () => {
            await expect(contract.setWhiteList(merkleRoot)).to.be.revertedWithCustomError(contract, 'OwnableUnauthorizedAccount');
        });
    
        it("multiwallet can set whitelist", async () => {
            await multiWallet.executeTransaction(0);
                // check users
            expect(await contract.whiteList()).to.equal(merkleRoot);
            expect(await contract.inWhiteList(signers[50].address, _proof(signers[50]))).to.equal(false);
            expect(await contract.inWhiteList(signers[51].address, _proof(signers[51]))).to.equal(true);
        });

        it("non-moderator cannot set black list", async () => {
            await expect(contract.connect(signers[5]).setToBlackList(signers[99].address, true)).to.be.revertedWithCustomError(contract, 'AccessControlUnauthorizedAccount');
        });

        it("moderator can set black list", async () => {
            await contract.connect(signers[10]).setToBlackList(signers[99].address, true);
            expect(await contract.blackList(signers[99].address)).to.equal(true);
        });

        it("non-owner cannot upgrade", async () => {
            await expect(contract.connect(signers[5]).changeImplementation(implementationV2.address, "1.0.1")).to.be.revertedWithCustomError(contract, 'OwnableUnauthorizedAccount');
        });
    });

    context("Permissions works correctly", async function(){
        it("signed mint with valid signature", async () => {
            await contract.connect(signers[8]).setState(2);
            sign = await _signForMint(signers[20], "1.0.0");
            await contract.connect(signers[21]).signedMint(signers[20].address, sign.v, sign.r, sign.s, {
                value: ethers.utils.parseEther("0.05"),
            });
            expect( await contract.ownerOf(1)).to.equal(signers[20].address);
            // reply attack
            await expect(contract.connect(signers[20]).signedMint(signers[20].address, sign.v, sign.r, sign.s, {
                value: ethers.utils.parseEther("0.05"),
            })).to.be.revertedWithCustomError(contract, 'InvalidSignature');
            expect(await ethers.provider.getBalance(contract.address)).to.equal(ethers.utils.parseEther("0.05"));
        });
    });

    context("Fill storage and upgrade", async function () {
        beforeEach(async function () {
            await contract.setMintPrice(ethers.utils.parseEther("2.5"));
            await contract.connect(signers[8]).setState(2);
            await contract.connect(signers[90]).mint({
                value: ethers.utils.parseEther("2.5"),
            });
            await contract.changeImplementation(implementationV2.address, "1.0.1");
        });

        it("success read storage", async function () {
            expect(await proxy.getImplementation()).to.equal(implementationV2.address);
            expect(await contract.ownerOf(1)).to.equal(signers[90].address);
            expect(await ethers.provider.getBalance(contract.address)).to.equal(ethers.utils.parseEther("2.5"));
            expect(await contract.version()).to.equal("1.0.1");
            expect(await contract.mintPrice()).to.equal(ethers.utils.parseEther("2.5"));
        });

        it("now multiwallet cannot set white list", async () => {
            await expect(multiWallet.executeTransaction(0)).to.be.reverted;
        });

        it("only owner can set white list", async () => {
            await contract.setWhiteList(merkleRoot);
            expect(await contract.whiteList()).to.equal(merkleRoot);
        });

        it("award is correct", async () => {
            sign = await _signForClose();
            await contract.connect(signers[60]).signedClose("ipfs://awesome_collection/", sign.v, sign.r, sign.s);
            expect( await contract.tokenURI(1)).to.equal('ipfs://awesome_collection/1');
            expect(await ethers.provider.getBalance(contract.address)).to.equal(ethers.utils.parseEther("0.5"));
        });

        it("new domainSeparator works correctly", async () => {
            sign = await _signForMint(signers[20], "1.0.1");
            await contract.connect(signers[21]).signedMint(signers[20].address, sign.v, sign.r, sign.s, {
                value: ethers.utils.parseEther("2.5"),
            });
            expect( await contract.ownerOf(2)).to.equal(signers[20].address);
        });

        it("re-initialisation is disabled", async function () {
            await expect(contract.initialize(10, "ipfs://new_metadata/", ethers.utils.parseEther("0.05"), multiWallet.address)).to.be.reverted;
        });
    })
   
});