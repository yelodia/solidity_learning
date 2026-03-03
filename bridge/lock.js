import "dotenv/config";
import { createPublicClient, createWalletClient, http, parseEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { bridgeAbi, tokenApproveAbi } from "./abi.js";

const CHAIN_A_RPC = process.env.CHAIN_A_RPC || "http://127.0.0.1:8545";
const CHAIN_A_ID = Number(process.env.CHAIN_A_ID ?? "31337");
const BRIDGE_A_ADDRESS = process.env.BRIDGE_A_ADDRESS;

const [userPrivateKey, amountStr] = process.argv.slice(2);
if (!BRIDGE_A_ADDRESS || !userPrivateKey || !amountStr) {
  console.error("Usage: node lock.js <privateKey> <amountInEther>");
  process.exit(1);
}

const chainA = {
  rpc: CHAIN_A_RPC,
  chainId: CHAIN_A_ID,
  bridge: BRIDGE_A_ADDRESS,
};

async function main() {
  const amount = parseEther(amountStr.trim());
  const transport = http(chainA.rpc);
  const account = privateKeyToAccount(userPrivateKey.startsWith("0x") ? userPrivateKey : `0x${userPrivateKey}`);
  const publicClient = createPublicClient({ transport, chain: { id: chainA.chainId } });
  const walletClient = createWalletClient({
    account,
    transport,
    chain: { id: chainA.chainId },
  });

  const tokenAddress = await publicClient.readContract({
    address: chainA.bridge,
    abi: bridgeAbi,
    functionName: "token",
  });

  console.log("Approve", amount.toString(), "to bridge", chainA.bridge);
  const approveHash = await walletClient.writeContract({
    address: tokenAddress,
    abi: tokenApproveAbi,
    functionName: "approve",
    args: [chainA.bridge, amount],
  });
  await publicClient.waitForTransactionReceipt({ hash: approveHash });
  console.log("Approved tx:", approveHash);

  console.log("Lock", amount.toString(), "on bridge");
  const lockHash = await walletClient.writeContract({
    address: chainA.bridge,
    abi: bridgeAbi,
    functionName: "lock",
    args: [amount],
  });
  await publicClient.waitForTransactionReceipt({ hash: lockHash });
  console.log("Lock tx:", lockHash);
  console.log("Done. Run relayer to release on the other chain.");
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
