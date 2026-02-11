import "dotenv/config";
import { createPublicClient, http, formatEther } from "viem";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";

const __dirname = dirname(fileURLToPath(import.meta.url));

const MIMIMI_CAT_ADDRESS = "0x0817f82aeB724b8000BA6c10496ADf25B1480f7F";
const SEPOLIA_CHAIN_ID = 11155111;

const abi = JSON.parse(
  readFileSync(join(__dirname, "abi", "MimimiCat.json"), "utf8")
);

function getRpcUrl() {
  const url = process.env.SEPOLIA_RPC;
  if (!url) throw new Error("Укажите SEPOLIA_RPC в .env");
  return url;
}

function getTokenId() {
  const arg = process.argv.find((a) => a.startsWith("--token-id="));
  if (arg) {
    const val = arg.slice("--token-id=".length).trim();
    const n = Number(val);
    if (!Number.isInteger(n) || n < 0) throw new Error("--token-id должен быть неотрицательным целым");
    return BigInt(n);
  }
  const pos = process.argv[2];
  if (pos !== undefined && pos !== "") {
    const n = Number(pos);
    if (!Number.isInteger(n) || n < 0) throw new Error("tokenId должен быть неотрицательным целым");
    return BigInt(n);
  }
  return null;
}

const chain = {
  id: SEPOLIA_CHAIN_ID,
  name: "Sepolia",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: [] } },
};

async function main() {
  const rpcUrl = getRpcUrl();
  chain.rpcUrls.default.http = [rpcUrl];

  const publicClient = createPublicClient({
    chain,
    transport: http(rpcUrl),
  });

  const tokenId = getTokenId();

  const [name, symbol, state, maxSupply, mintPrice, multiSigner, whiteList] =
    await Promise.all([
      publicClient.readContract({ address: MIMIMI_CAT_ADDRESS, abi, functionName: "name" }),
      publicClient.readContract({ address: MIMIMI_CAT_ADDRESS, abi, functionName: "symbol" }),
      publicClient.readContract({ address: MIMIMI_CAT_ADDRESS, abi, functionName: "state" }),
      publicClient.readContract({ address: MIMIMI_CAT_ADDRESS, abi, functionName: "MAX_SUPPLY" }),
      publicClient.readContract({ address: MIMIMI_CAT_ADDRESS, abi, functionName: "mintPrice" }),
      publicClient.readContract({ address: MIMIMI_CAT_ADDRESS, abi, functionName: "multiSigner" }),
      publicClient.readContract({ address: MIMIMI_CAT_ADDRESS, abi, functionName: "whiteList" }),
    ]);

  console.log("name:", name);
  console.log("symbol:", symbol);
  console.log("state:", state);
  console.log("MAX_SUPPLY:", maxSupply.toString());
  console.log("mintPrice:", formatEther(mintPrice), "ETH");
  console.log("multiSigner:", multiSigner);
  console.log("whiteList:", whiteList);

  if (tokenId !== null) {
    const [tokenURI, ownerOf] = await Promise.all([
      publicClient.readContract({
        address: MIMIMI_CAT_ADDRESS,
        abi,
        functionName: "tokenURI",
        args: [tokenId],
      }),
      publicClient.readContract({
        address: MIMIMI_CAT_ADDRESS,
        abi,
        functionName: "ownerOf",
        args: [tokenId],
      }),
    ]);
    console.log("tokenURI:", tokenURI);
    console.log("ownerOf:", ownerOf);
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
