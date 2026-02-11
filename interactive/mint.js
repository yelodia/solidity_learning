import "dotenv/config";
import { createPublicClient, createWalletClient, http, formatEther } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));

const MIMIMI_CAT_ADDRESS = "0x0817f82aeB724b8000BA6c10496ADf25B1480f7F";
const SEPOLIA_CHAIN_ID = 11155111;

const abi = JSON.parse(
  readFileSync(join(__dirname, "abi", "MimimiCat.json"), "utf8")
);

function getPrivateKey() {
  const arg = process.argv.find((a) => a.startsWith("--private-key="));
  if (!arg) {
    throw new Error("Передайте приватный ключ: node mint.js --private-key=0x...");
  }
  const key = arg.slice("--private-key=".length).trim();
  return key.startsWith("0x") ? key : `0x${key}`;
}

function getRpcUrl() {
  const url = process.env.SEPOLIA_RPC;
  if (!url) {
    throw new Error("Укажите SEPOLIA_RPC в .env");
  }
  return url;
}

const chain = {
  id: SEPOLIA_CHAIN_ID,
  name: "Sepolia",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: [] } },
};

async function main() {
  const privateKey = getPrivateKey();
  const rpcUrl = getRpcUrl();
  chain.rpcUrls.default.http = [rpcUrl];

  const transport = http(rpcUrl);
  const publicClient = createPublicClient({ chain, transport });
  const account = privateKeyToAccount(privateKey);
  const walletClient = createWalletClient({
    account,
    chain,
    transport,
  });

  const balance = await publicClient.getBalance({ address: account.address });
  console.log("Wallet balance:", formatEther(balance), "ETH");

  console.log("Fetching mint price from contract...");
  const mintPrice = await publicClient.readContract({
    address: MIMIMI_CAT_ADDRESS,
    abi,
    functionName: "mintPrice",
  });
  console.log("Mint price (wei):", mintPrice.toString());

  console.log("Estimating gas...");
  const gasEstimate = await publicClient.estimateContractGas({
    address: MIMIMI_CAT_ADDRESS,
    abi,
    functionName: "mint",
    account: account.address,
    value: mintPrice,
  });
  console.log("estimateGas:", gasEstimate.toString());

  const gasPrice = await publicClient.getGasPrice();
  const estimatedCost = mintPrice + gasEstimate * gasPrice;

  if (balance < estimatedCost) {
    console.error(
      "Ошибка: недостаточно средств. Баланс:",
      formatEther(balance),
      "ETH. Требуется (цена минта + газ):",
      formatEther(estimatedCost),
      "ETH."
    );
    process.exit(1);
  }

  console.log("Sending mint transaction...");
  const hash = await walletClient.writeContract({
    address: MIMIMI_CAT_ADDRESS,
    abi,
    functionName: "mint",
    value: mintPrice,
  });

  console.log("Transaction hash:", hash);
  console.log("Waiting for transaction receipt...");

  const receipt = await publicClient.waitForTransactionReceipt({ hash });

  console.log("\n--- Result ---");
  console.log("Transaction hash:", hash);
  console.log("estimateGas:", gasEstimate.toString());
  console.log(
    "Receipt:",
    JSON.stringify(
      receipt,
      (_, v) => (typeof v === "bigint" ? v.toString() : v),
      2
    )
  );
  console.log("Status:", receipt.status === "success" ? "success" : "reverted");
  if (receipt.gasUsed !== undefined) {
    console.log("Gas used:", receipt.gasUsed.toString());
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
