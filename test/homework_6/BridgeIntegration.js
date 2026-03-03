/*global describe, it, beforeEach*/
import { expect } from "chai";
import { network } from "hardhat";

const { ethers } = await network.connect();

const REMOTE_CHAIN_ID_A = 97n;
const REMOTE_CHAIN_ID_B = 80002n;
const INITIAL_SUPPLY = ethers.parseEther("10000");
const LOCK_AMOUNT = ethers.parseEther("100");

describe("Bridge integration", function () {
  let tokenA;
  let tokenB;
  let bridgeA;
  let bridgeB;
  let user;

  beforeEach(async function () {
    const [deployer, u] = await ethers.getSigners();
    user = u;

    const BridgeableToken = await ethers.getContractFactory("BridgeableToken");
    const Bridge = await ethers.getContractFactory("Bridge");

    tokenA = await BridgeableToken.deploy("Bridgeable yel", "YEL", INITIAL_SUPPLY);
    bridgeA = await Bridge.deploy(tokenA, Number(REMOTE_CHAIN_ID_A));
    await tokenA.setBridge(await bridgeA.getAddress());

    tokenB = await BridgeableToken.deploy("Bridgeable yel", "YEL", 0n);
    bridgeB = await Bridge.deploy(tokenB, Number(REMOTE_CHAIN_ID_B));
    await tokenB.setBridge(await bridgeB.getAddress());

    await tokenA.transfer(user.address, ethers.parseEther("1000"));
  });

  it("lock emits BridgeLock, burns supply", async function () {
    await tokenA.connect(user).approve(await bridgeA.getAddress(), LOCK_AMOUNT);
    const tx = await bridgeA.connect(user).lock(LOCK_AMOUNT);
    const receipt = await tx.wait();
    expect(receipt).to.not.be.null;
    const iface = new ethers.Interface([
      "event BridgeLock(address indexed user, uint256 amount, uint64 chainId, uint64 nonce)",
    ]);
    let parsed = null;
    for (const log of receipt.logs) {
      try {
        const p = iface.parseLog({ topics: log.topics, data: log.data });
        if (p && p.name === "BridgeLock") {
          parsed = p;
          break;
        }
      } catch {
        // skip
      }
    }
    expect(parsed).to.not.be.null;
    expect(parsed.args.user).to.equal(user.address);
    expect(parsed.args.amount).to.equal(LOCK_AMOUNT);
    expect(parsed.args.nonce).to.equal(1n);
    expect(await tokenA.totalSupply()).to.equal(INITIAL_SUPPLY - LOCK_AMOUNT);
  });

  it("release mints; duplicate reverts AlreadyProcessed", async function () {
    const originChainId = REMOTE_CHAIN_ID_B;
    const nonce = 1n;
    await bridgeB.release(user.address, LOCK_AMOUNT, Number(originChainId), Number(nonce));
    expect(await tokenB.balanceOf(user.address)).to.equal(LOCK_AMOUNT);

    await expect(
      bridgeB.release(user.address, LOCK_AMOUNT, Number(originChainId), Number(nonce))
    ).to.be.revertedWithCustomError(bridgeB, "AlreadyProcessed");
  });

  it("release reverts WrongChain on wrong chain", async function () {
    await expect(
      bridgeB.release(user.address, LOCK_AMOUNT, 1, 1)
    ).to.be.revertedWithCustomError(bridgeB, "WrongChain");
  });
});
