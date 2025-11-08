/*global describe, context, beforeEach, it*/
import { expect } from "chai";
import { network } from "hardhat";
import hre from "hardhat";
import StorageHelper from "../../helpers/StorageHelper.js";

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
    let helper;

    // helpers

    async function SharedMintNotOpened() {
        it("cannot mint", async () => {
            await expect(contract.connect(signers[22]).mint({
                value: ethers.parseEther("0.05"),
            })).to.be.revertedWithCustomError(contract, 'MCTMintIsNotOpened');
        });

        it("cannot signed mint", async () => {
            let sign = await _signForMint(signers[20]);
            await expect(contract.connect(signers[21]).signedMint(signers[20].address, sign.v, sign.r, sign.s, {
                value: ethers.parseEther("0.05"),
            })).to.be.revertedWithCustomError(contract, 'MCTMintIsNotOpened');
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
        await hre.tasks.getTask("storage-layout").subtasks.get('export').run();
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

        helper = new StorageHelper(
            './storage_layout/contracts/homework_4/mimimiCat.sol:MimimiCat.json',
            contract.target,
            ethers
        );
    });

    context("Initialization", async function () {
        it("Correctly constructs nft", async () => {
            expect(await contract.owner()).to.equal(deployer.address);
            expect(await contract.MAX_SUPPLY()).to.equal(15);
            expect(await contract.mintPrice()).to.equal(ethers.parseEther("0.05"));
            expect(await contract.name()).to.equal("MimimiCat");
            expect(await contract.state()).to.equal(1);
        });
    });

    context("Add stakeholders", async function () {
        it("non-owner cannot set stakeholders", async () => {
            await expect(contract.connect(signers[5]).addStakeHolders([signers[0].address, signers[1].address])).to.be.revertedWithCustomError(contract, 'OwnableUnauthorizedAccount');
        });

        it("only owner cannot set stakeholders", async () => {
            await contract.addStakeHolders([signers[0].address, signers[1].address]);
        });
    });

    context("Add moderators", async function () {
        it("non-owner cannot set moderators", async () => {
            await expect(contract.connect(signers[5]).addModerators([signers[8].address, signers[9].address, signers[10].address])).to.be.revertedWithCustomError(contract, 'OwnableUnauthorizedAccount');
        });

        it("only owner cannot set moderators", async () => {
            await contract.addModerators([signers[8].address, signers[9].address, signers[10].address]);
        });
    });

    context("Set mint price", async function () {
        it("non-stakeholder cannot set mint price", async () => {
            await expect(contract.connect(signers[5]).setMintPrice(ethers.parseEther("0.1"))).to.be.revertedWithCustomError(contract, 'AccessControlUnauthorizedAccount');
        });

        it("stakeholder can set mint price", async () => {
            await contract.addStakeHolders([signers[0].address, signers[1].address]);
            await contract.connect(signers[1]).setMintPrice(ethers.parseEther("0.1"));
            expect(await contract.mintPrice()).to.equal(ethers.parseEther("0.1"));
        });
    });

    context("Set to black list", async function () {
        it("non-moderator cannot set black list", async () => {
            await expect(contract.connect(signers[5]).setToBlackList(signers[99].address, true)).to.be.revertedWithCustomError(contract, 'AccessControlUnauthorizedAccount');
        });

        it("moderator can set black list", async () => {
            await contract.addModerators([signers[8].address, signers[9].address, signers[10].address]);
            await contract.connect(signers[10]).setToBlackList(signers[99].address, true);
            await contract.connect(signers[9]).setToBlackList(signers[98].address, true);
            expect(await contract.blackList(signers[99].address)).to.equal(true);
            expect(await contract.blackList(signers[98].address)).to.equal(true);
        });
    });

    context("Set white list", async function () {
        it("non-multiwallet cannot set white list", async () => {
            await expect(contract.connect(signers[0]).setWhiteList(merkleRoot)).to.be.revertedWithCustomError(contract, 'OwnableUnauthorizedAccount');
        });

        it("multiwallet cannot set whitelist if insufficient confirmations", async () => {
            await multiWallet.submitTransaction(contract.target, 0, whitelistAbi);
            await multiWallet.connect(signers[1]).confirmTransaction(0);
            await expect(multiWallet.executeTransaction(1)).to.be.revert(ethers);
        });

        it("multiwallet can set whitelist", async () => {
            await multiWallet.submitTransaction(contract.target, 0, whitelistAbi);
            for(var i=1; i<6; i++) {
                await multiWallet.connect(signers[i]).confirmTransaction(0);
            }
            await multiWallet.executeTransaction(0);
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
            await multiWallet.submitTransaction(contract.target, 0, closeAbi);
            for(var i=1; i<6; i++) {
                await multiWallet.connect(signers[i]).confirmTransaction(0);
            }
            await multiWallet.executeTransaction(0);
            expect(await contract.state()).to.equal(3);

            await helper.setVariable('_owners', signers[90].address, 1);
            expect( await contract.tokenURI(1)).to.equal('ipfs://visible_metadata/1');
        });
    });

    context("signedClose", async function () {
        beforeEach(async function () {
            await helper.setBalance(contract.target, ethers.parseEther("2.5"));
            await helper.setVariable('state', 2);
            await helper.setVariable('_owners', signers[90].address, 1);
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

    context("Set state", async function () {
        beforeEach(async function () {
            await contract.addModerators([signers[8].address, signers[9].address, signers[10].address]);
        });

        it("non-moderator cannot set state", async () => {
            await expect(contract.connect(signers[53]).setState(2)).to.be.revertedWithCustomError(contract, 'AccessControlUnauthorizedAccount');
        });

        it("moderator can set state", async () => {
            await contract.connect(signers[9]).setState(2)
            expect(await contract.state()).to.equal(2);
            await contract.connect(signers[10]).setState(1)
            expect(await contract.state()).to.equal(1);
        });

        it("moderator cannot set closed state", async () => {
            await expect(contract.connect(signers[9]).setState(3)).to.be.revertedWithCustomError(contract, 'MCTInvalidTransition');
        });

        it("cannot set state if closed", async () => {
            await helper.setVariable('state', 3);
            await expect(contract.connect(signers[9]).setState(2)).to.be.revertedWithCustomError(contract, 'MCTInvalidTransition');
        });
    });

    context("Token URI", async function () {
        it("cannot get for non-minted", async () => {
            await expect(contract.tokenURI(1)).to.be.revertedWithCustomError(contract, 'ERC721NonexistentToken');
        });

        it("inivisible metadata if not closed", async () => {
            await helper.setVariable('_owners', signers[90].address, 1);
            expect( await contract.tokenURI(1)).to.equal('ipfs://hidden_metadata');
        });

        it("visible metadata if closed", async () => {
            await helper.setVariable('_owners', signers[90].address, 1);
            await helper.setVariable('baseURI', 'ipfs://awesome_metadata/');
            await helper.setVariable('state', 3);
            expect( await contract.tokenURI(1)).to.equal('ipfs://awesome_metadata/1');
        });
    });

    context("Mint", async function () {
        context("When mint is paused", async function () {
            await SharedMintNotOpened();
        });

        context("When mint is opened", async function () {
            beforeEach(async function () {
                await helper.setVariable('state', 2);
            });

            it("user in black list", async () => {
                await helper.setVariable('blackList', true, signers[99].address);
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

        context("When mint is closed", async function () {
            beforeEach(async function () {
                await helper.setVariable('state', 3);
            });
            await SharedMintNotOpened();
        });
    });

    context("Free Mint", async function () {
        context("When mint is paused", async function () {
            it("cannot free mint", async () => {
                await expect(contract.connect(signers[51]).freeMint(_proof(signers[51]))).to.be.revertedWithCustomError(contract, 'MCTMintIsNotOpened');
            });
        });

        context("When mint is opened", async function () {
            beforeEach(async function () {
                await helper.setVariable('state', 2);
                await helper.setVariable('whiteList', merkleRoot);
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

            it("free mint with invalid signature", async () => {
                let sign = await _signForFreeMint(signers[53]);
                await expect(contract.connect(signers[21]).signedFreeMint(signers[21].address, _proof(signers[53]), sign.v, sign.r, sign.s)).to.be.revertedWithCustomError(contract, 'InvalidSignature');
            });

            it("free mint with valid signature", async () => {
                let sign = await _signForFreeMint(signers[53]);
                await contract.connect(signers[21]).signedFreeMint(signers[53].address, _proof(signers[53]), sign.v, sign.r, sign.s);
                expect( await contract.ownerOf(1)).to.equal(signers[53].address);
            });
        });

        context("When mint is closed", async function () {
            it("cannot free mint", async () => {
                await helper.setVariable('state', 3);
                await expect(contract.connect(signers[51]).freeMint(_proof(signers[51]))).to.be.revertedWithCustomError(contract, 'MCTMintIsNotOpened');
            });
        });
    });

    context("Exceeded mint limit", async function () {
        beforeEach(async function () {
            await helper.setVariable('state', 2);
            await helper.setVariable('whiteList', merkleRoot);
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

    context("Withdraw", async function () {
        beforeEach(async function () {
            await helper.setBalance(contract.target, ethers.parseEther("5"));
            await contract.addStakeHolders([signers[0].address, signers[1].address]);
        });

        it("stakeholder cannot withdraw if state is paused", async () => {
            await expect(contract.connect(signers[1]).withdraw(ethers.parseEther("1"))).to.be.revertedWithCustomError(contract, 'MCTMintIsNotClosed');
        });

        it("stakeholder cannot withdraw if state is opened", async () => {
            await helper.setVariable('state', 2);
            await expect(contract.connect(signers[1]).withdraw(ethers.parseEther("1"))).to.be.revertedWithCustomError(contract, 'MCTMintIsNotClosed');
        });

        it("non-stakeholder cannot withdraw", async () => {
            await helper.setVariable('state', 3);
            await expect(contract.connect(signers[9]).withdraw(ethers.parseEther("1"))).to.be.revertedWithCustomError(contract, 'AccessControlUnauthorizedAccount');
        });

        it("stakeholder can withdraw", async () => {
            await helper.setVariable('state', 3);
            await contract.connect(signers[1]).withdraw(ethers.parseEther("1"));
            expect(await ethers.provider.getBalance(contract.target)).to.equal(ethers.parseEther("4"));
        });
    });

    context("Permit", async function () {
        beforeEach(async function () {
            await helper.setVariable('_owners', signers[90].address, 1);
        });

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