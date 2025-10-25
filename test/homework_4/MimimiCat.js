/*global describe, context, beforeEach, it*/
import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

import { MerkleTree } from 'merkletreejs';
import keccak256 from 'keccak256';

describe("MimimmiCat", function () {
    let signers;
    let deployer;
    let contract;
    let multiWallet;
    let snapshotId;

    let abiFunc = ["function close(string _uri)", "function setWhiteList(bytes32 _whiteList)"];
    let iface = new ethers.Interface(abiFunc);
    let closeAbi;
    let whitelistAbi;
    let merkleTree;
    let merkleRoot;

    // helpers
    async function SetWhitelist() {
        await multiWallet.connect(signers[10]).confirmTransaction(1);
        await multiWallet.executeTransaction(1);
    }

    async function Close() {
        await multiWallet.connect(signers[10]).confirmTransaction(0);
        await multiWallet.executeTransaction(0);
    }

    async function SharedSetState(name, val) {
        it("can set "+name+" state", async () => {
            await contract.connect(signers[8]).setState(val);
            expect(await contract.state()).to.equal(val);
        });

        it("non-moderator cannot set "+name+" state", async () => {
            await expect(contract.connect(signers[5]).setState(val)).to.be.revertedWithCustomError(contract, 'AccessControlUnauthorizedAccount');
        });

        it("cannot set close state", async () => {
            await expect(contract.connect(signers[9]).setState(3)).to.be.revertedWithCustomError(contract, 'MCTInvalidTransition');
        });
    }

    async function SharedMintNotOpened() {
        it("cannot mint", async () => {
            await expect(contract.connect(signers[22]).mint({
                value: ethers.parseEther("0.05"),
            })).to.be.revertedWithCustomError(contract, 'MCTMintIsNotOpened');
        });
        it("cannot free mint", async () => {
            await expect(contract.connect(signers[51]).freeMint(_proof(signers[51]))).to.be.revertedWithCustomError(contract, 'MCTMintIsNotOpened');
        });
    }

    function _proof(signer) {
        return merkleTree.getHexProof(keccak256(signer.address));
    }

    function _domain() {
        return {
            name: "MimimiCat",
            version: '1.0.0',
            chainId: 31337,
            verifyingContract: contract.target
        }
    }

    async function _signForMint(signer) {
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
        const signature = await signer.signTypedData(_domain(), types, message);
	    return ethers.Signature.from(signature);
    }

    async function _signForFreeMint(signer) {
        const types = {
            FreeMint: [
              { name: "owner", type: "address" },
              { name: "proof", type: "bytes32[]" },
              { name: "nonce", type: "uint256" },
            ],
          };
        let nonce = await contract.nonces(signer.address);
        const message = {
            owner: signer.address,
            proof: _proof(signer),
            nonce: nonce,
          };
        const signature = await signer.signTypedData(_domain(), types, message);
	    return ethers.Signature.from(signature);
    }

    async function _signForPermit(signer, spender, tokenId) {
        const types = {
            Permit: [
              { name: "owner", type: "address" },
              { name: "spender", type: "address" },
              { name: "tokenId", type: "uint256" },
              { name: "nonce", type: "uint256" },
            ],
          };
        let nonce = await contract.nonces(signer.address);
        const message = {
            owner: signer.address,
            spender: spender.address,
            tokenId: tokenId,
            nonce: nonce,
          };
        const signature = await signer.signTypedData(_domain(), types, message);
	    return ethers.Signature.from(signature);
    }

    async function _signForClose() {
        let domain = await contract.domainSeparator();
        let messageHash = ethers.solidityPackedKeccak256(
            ['bytes32', 'string'], 
            [domain, 'ipfs://awesome_collection/']
        );
        let sign = await deployer.signMessage(ethers.getBytes(messageHash));
        return ethers.Signature.from(sign);
    }

    // start tests
    before(async function () {
        snapshotId = await ethers.provider.send('evm_snapshot');
        signers = await ethers.getSigners();
        closeAbi = iface.encodeFunctionData('close', ["ipfs://visible_metadata/"]);

        var leafNodes = signers.slice(51,56).map(signer => keccak256(signer.address));
        merkleTree = new MerkleTree(leafNodes, keccak256, {sortPairs: true});
        merkleRoot = '0x'+merkleTree.getRoot().toString('hex');
        whitelistAbi = iface.encodeFunctionData('setWhiteList', [merkleRoot]);
    });

    after(async () => {
        await ethers.provider.send("evm_revert", [snapshotId]);
    });

    beforeEach(async function () {
        // Accounts
        deployer = signers[0];

        // Contracts
        const MultiSigWallet = await ethers.getContractFactory("MultiSigWallet");
        multiWallet = await MultiSigWallet.deploy(signers.slice(0,11).map(function(em){return em.address}), 5);
        
        const MimimiCat = await ethers.getContractFactory("MimimiCat");
        contract = await MimimiCat.deploy(15, 5, "ipfs://hidden_metadata", ethers.parseEther("0.05"), multiWallet.target);

        // settings
        await contract.addStakeHolders([signers[0].address, signers[1].address]);
        await contract.addModerators([signers[8].address, signers[9].address, signers[10].address]);

        await multiWallet.submitTransaction(contract.target, 0, closeAbi);
        await multiWallet.submitTransaction(contract.target, 0, whitelistAbi);

        for(var i=1; i<5; i++) {
            await multiWallet.connect(signers[i]).confirmTransaction(0);
            await multiWallet.connect(signers[i]).confirmTransaction(1);
        }
    });

    context("Initialization", async function () {
        it("Correctly constructs nft", async () => {
            expect(await contract.owner()).to.equal(deployer.address);
            expect(await contract.maxSupply()).to.equal(15);
            expect(await contract.mintPrice()).to.equal(ethers.parseEther("0.05"));
            expect(await contract.name()).to.equal("MimimiCat");
            expect(await contract.state()).to.equal(1);
        });
    });

    context("Set mint price", async function () {
        it("non-stakeholder cannot set mint price", async () => {
            await expect(contract.connect(signers[5]).setMintPrice(ethers.parseEther("0.1"))).to.be.revertedWithCustomError(contract, 'AccessControlUnauthorizedAccount');
        });

        it("stakeholder can set mint price", async () => {
            await contract.connect(signers[1]).setMintPrice(ethers.parseEther("0.1"));
            expect(await contract.mintPrice()).to.equal(ethers.parseEther("0.1"));
        });
    });

    context("Set to black list", async function () {
        it("non-moderator cannot set black list", async () => {
            await expect(contract.connect(signers[5]).setToBlackList(signers[99].address, true)).to.be.revertedWithCustomError(contract, 'AccessControlUnauthorizedAccount');
        });

        it("moderator can set black list", async () => {
            await contract.connect(signers[10]).setToBlackList(signers[99].address, true);
            expect(await contract.blackList(signers[99].address)).to.equal(true);
        });
    });

    context("Set white list", async function () {
        it("non-multiwallet cannot set white list", async () => {
            await expect(contract.connect(signers[0]).setWhiteList(merkleRoot)).to.be.revertedWithCustomError(contract, 'OwnableUnauthorizedAccount');
        });

        it("multiwallet cannot set whitelist if insufficient confirmations", async () => {
            await expect(multiWallet.executeTransaction(1)).to.be.revert(ethers);
        });

        it("multiwallet can set whitelist", async () => {
            await SetWhitelist();
            // check users
            expect(await contract.whiteList()).to.equal(merkleRoot);
            expect(await contract.inWhiteList(signers[50].address, _proof(signers[50]))).to.equal(false);
            expect(await contract.inWhiteList(signers[51].address, _proof(signers[51]))).to.equal(true);
        });
    });

    context("Close", async function () {
        it("non-multiwallet cannot close mint", async () => {
            await expect(contract.connect(signers[0]).close("ipfs://visible_metadata/")).to.be.revertedWithCustomError(contract, 'OwnableUnauthorizedAccount');
        });

        it("cannot close if insufficient confirmations", async () => {
            await expect(multiWallet.executeTransaction(0)).to.be.revert(ethers);
        });

        it("multiwallet can close", async () => {
            await Close();
            expect(await contract.state()).to.equal(3);
        });
    });

    context("signedClose", async function () {
        beforeEach(async function () {
            await contract.connect(signers[8]).setState(2);
            await contract.setMintPrice(ethers.parseEther("2.5"));
            await contract.connect(signers[90]).mint({
                value: ethers.parseEther("2.5"),
            });
        });

        it("close with invalid url", async () => {
            let sign = await _signForClose();
            await expect(contract.connect(signers[60]).signedClose("ipfs://another_collection/", sign.v, sign.r, sign.s)).to.be.revertedWithCustomError(contract, 'InvalidSignature');
        });

        it("close with valid url", async () => {
            let sign = await _signForClose();
            await contract.connect(signers[60]).signedClose("ipfs://awesome_collection/", sign.v, sign.r, sign.s);
            expect( await contract.tokenURI(1)).to.equal('ipfs://awesome_collection/1');
            expect(await ethers.provider.getBalance(contract.target)).to.equal(ethers.parseEther("0.5"));
            // try to reply
            await expect(contract.connect(signers[60]).signedClose("ipfs://awesome_collection/", sign.v, sign.r, sign.s)).to.be.revertedWithCustomError(contract, 'MCTAlreadyClosed');
        });
    });

    context("Withdraw", async function () {
        it("non-stakeholder cannot withdraw", async () => {
            await expect(contract.connect(signers[9]).withdraw(ethers.parseEther("0.05"))).to.be.revertedWithCustomError(contract, 'AccessControlUnauthorizedAccount');
        });
    });

    context("When mint is paused", async function () {
        context("Set state", async function () {
            await SharedSetState("open", 2);
        });
        
        context("Mint", async function () {
            await SharedMintNotOpened();
        });
    });

    context("When mint is opened", async function () {

        beforeEach(async function () {
            await contract.connect(signers[8]).setState(2);
        });

        context("Set state", async function () {
            await SharedSetState("pause", 1);
        });

        context("token URI", async function () {
            it("error if token is not minted", async () => {
                await expect(contract.tokenURI(1)).to.be.revert(ethers);
            });
            it("success if token is minted", async () => {
                await contract.connect(signers[22]).mint({
                    value: ethers.parseEther("0.05"),
                });
                expect( await contract.tokenURI(1)).to.equal('ipfs://hidden_metadata');
            });
        });

        context("Withdraw", async function () {
            it("cannot withdraw", async () => {
                await contract.connect(signers[90]).mint({
                    value: ethers.parseEther("0.05"),
                });
                await expect(contract.withdraw(ethers.parseEther("0.05"))).to.be.revertedWithCustomError(contract, 'MCTMintIsNotClosed');
            });
        });

        context("Mint", async function () {
            it("user in black list", async () => {
                await contract.connect(signers[10]).setToBlackList(signers[99].address, true);
                await expect(contract.connect(signers[99]).mint({
                    value: ethers.parseEther("0.05"),
                })).to.be.revertedWithCustomError(contract, 'MCTAdddresInBlackList');
            });

            it("invalid ethers", async () => {
                await expect(contract.connect(signers[90]).mint({
                    value: ethers.parseEther("0.01"),
                })).to.be.revertedWithCustomError(contract, 'MCTInvalidEthers');
            });

            it("success mint", async () => {
                await contract.connect(signers[90]).mint({
                    value: ethers.parseEther("0.05"),
                });
                expect( await contract.ownerOf(1)).to.equal(signers[90].address);
                expect(await ethers.provider.getBalance(contract.target)).to.equal(ethers.parseEther("0.05"));
            });

            it("signed mint with invalid signature", async () => {
                let sign = await _signForMint(signers[20]);
                await expect(contract.connect(signers[21]).signedMint(signers[21].address, sign.v, sign.r, sign.s, {
                    value: ethers.parseEther("0.05"),
                })).to.be.revertedWithCustomError(contract, 'InvalidSignature');
            });

            it("signed mint with valid signature", async () => {
                let sign = await _signForMint(signers[20]);
                await contract.connect(signers[21]).signedMint(signers[20].address, sign.v, sign.r, sign.s, {
                    value: ethers.parseEther("0.05"),
                });
                expect( await contract.ownerOf(1)).to.equal(signers[20].address);
                // reply attack
                await expect(contract.connect(signers[20]).signedMint(signers[20].address, sign.v, sign.r, sign.s, {
                    value: ethers.parseEther("0.05"),
                })).to.be.revertedWithCustomError(contract, 'InvalidSignature');
                expect(await ethers.provider.getBalance(contract.target)).to.equal(ethers.parseEther("0.05"));
            });
        });

        context("Free Mint", async function () {
            beforeEach(async function () {
                await SetWhitelist();
            });

            it("user is not in whitelist", async () => {
                await expect(contract.connect(signers[99]).freeMint(_proof(signers[99]))).to.be.revertedWithCustomError(contract, 'MCTAdddresNotInWiteList');
            });

            it("success mint", async () => {
                await contract.connect(signers[53]).freeMint(_proof(signers[53]));
                expect( await contract.ownerOf(1)).to.equal(signers[53].address);
            });

            it("error if address has minted", async () => {
                await contract.connect(signers[53]).freeMint(_proof(signers[53]));
                await expect(contract.connect(signers[53]).freeMint(_proof(signers[53]))).to.be.revertedWithCustomError(contract, 'MCTAlreadyHasFreeMint');
            });

            it("signed free mint with invalid signature", async () => {
                let sign = await _signForFreeMint(signers[53]);
                await expect(contract.connect(signers[21]).signedFreeMint(signers[21].address, _proof(signers[53]), sign.v, sign.r, sign.s)).to.be.revertedWithCustomError(contract, 'InvalidSignature');
            });

            it("signed free mint with valid signature", async () => {
                let sign = await _signForFreeMint(signers[53]);
                await contract.connect(signers[21]).signedFreeMint(signers[53].address, _proof(signers[53]), sign.v, sign.r, sign.s);
                expect( await contract.ownerOf(1)).to.equal(signers[53].address);
            });
        });

        context("Exceeded mint limit", async function () {
            beforeEach(async function () {
                await SetWhitelist();
            });

            it("fill free pool last", async () => {
                for (var i=70; i<80; i++) {
                    await contract.connect(signers[i]).mint({
                        value: ethers.parseEther("0.05"),
                    });
                }
                await expect(contract.connect(signers[70]).mint({
                    value: ethers.parseEther("0.05"),
                })).to.be.revertedWithCustomError(contract, 'MCTLimitExceed');
                // whitelist still can mint
                for (var i=51; i<56; i++) {
                    await contract.connect(signers[i]).freeMint(_proof(signers[i]));
                }
                expect( await contract.tokenURI(15)).to.equal('ipfs://hidden_metadata'); // token with max id is minted
            });

            it("fill free pool first", async () => {
                for (var i=51; i<56; i++) {
                    await contract.connect(signers[i]).freeMint(_proof(signers[i]));
                }
                for (var i=70; i<80; i++) {
                    await contract.connect(signers[i]).mint({
                        value: ethers.parseEther("0.05"),
                    });
                }
                await expect(contract.connect(signers[70]).mint({
                    value: ethers.parseEther("0.05"),
                })).to.be.revertedWithCustomError(contract, 'MCTLimitExceed');
                expect( await contract.tokenURI(15)).to.equal('ipfs://hidden_metadata'); // token with max id is minted
            });
        });

    });

    context("When mint is closed", async function () {

        beforeEach(async function () {
            await SetWhitelist();
            await contract.connect(signers[8]).setState(2);
            await contract.connect(signers[90]).mint({
                value: ethers.parseEther("0.05"),
            });
            await contract.connect(signers[53]).freeMint(_proof(signers[53]));
            await Close();
        });

        context("Set state", async function () {
            it("canot set open state", async () => {
                await expect(contract.connect(signers[9]).setState(1)).to.be.revertedWithCustomError(contract, 'MCTInvalidTransition');
            });
    
            it("canot set pause state", async () => {
                await expect(contract.connect(signers[9]).setState(2)).to.be.revertedWithCustomError(contract, 'MCTInvalidTransition');
            });
        });
        
        context("Mint", async function () {
            await SharedMintNotOpened();
        });

        context("token URI", async function () {
            it("with changed metadata", async () => {
                expect( await contract.tokenURI(1)).to.equal('ipfs://visible_metadata/1');
                expect( await contract.tokenURI(2)).to.equal('ipfs://visible_metadata/2');
            });
        });

        context("Withdraw", async function () {
            it("can withdraw", async () => {
                await contract.withdraw(ethers.parseEther("0.05"));
                expect(await ethers.provider.getBalance(contract.target)).to.equal(0);
            });
        });

        context("Permit", async function () {
            it("permit with invalid signature", async () => {
                let sign = await _signForPermit(signers[90], signers[70], 1);
                await expect(contract.connect(signers[60]).permit(signers[90].address, signers[60].address, 1, sign.v, sign.r, sign.s)).to.be.revertedWithCustomError(contract, 'InvalidSignature');
            });
    
            it("permit with valid signature", async () => {
                let sign = await _signForPermit(signers[90], signers[70], 1);
                await contract.connect(signers[60]).permit(signers[90].address, signers[70].address, 1, sign.v, sign.r, sign.s);
                expect( await contract.getApproved(1)).to.equal(signers[70].address);
            });
        });
    });
    
});