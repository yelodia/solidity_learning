import "dotenv/config";

// RPC и chainId для двух цепей (локальная сеть или Amoy/BSC)
const CHAIN_A_RPC = process.env.CHAIN_A_RPC || "http://127.0.0.1:8545";
const CHAIN_B_RPC = process.env.CHAIN_B_RPC || "http://127.0.0.1:8545";
const CHAIN_A_ID = Number(process.env.CHAIN_A_ID || "31337");
const CHAIN_B_ID = Number(process.env.CHAIN_B_ID || "31337");
const BRIDGE_A_ADDRESS = process.env.BRIDGE_A_ADDRESS;
const BRIDGE_B_ADDRESS = process.env.BRIDGE_B_ADDRESS;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

if (!BRIDGE_A_ADDRESS || !BRIDGE_B_ADDRESS || !PRIVATE_KEY) {
  throw new Error("Set BRIDGE_A_ADDRESS, BRIDGE_B_ADDRESS, PRIVATE_KEY in .env");
}

/** Конфиг релейера: две цепи и адреса контрактов моста на каждой */
export const config = {
  chainA: { rpc: CHAIN_A_RPC, chainId: CHAIN_A_ID, bridge: BRIDGE_A_ADDRESS },
  chainB: { rpc: CHAIN_B_RPC, chainId: CHAIN_B_ID, bridge: BRIDGE_B_ADDRESS },
  privateKey: PRIVATE_KEY,
};
