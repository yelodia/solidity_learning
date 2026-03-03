/*
 Релейер моста: подписывается на событие BridgeLock на обеих цепях и вызывает
 release(to, amount, originChainId, nonce) на противоположной цепи.
*/
import { createPublicClient, createWalletClient, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";
import { config } from "./config.js";
import { bridgeAbi } from "./abi.js";

/** Создаёт клиенты для чтения и подписи транзакций по конфигу одной цепи */
function createChainClients(chainConfig) {
  const transport = http(chainConfig.rpc);
  const publicClient = createPublicClient({ transport, chain: { id: chainConfig.chainId } });
  const account = privateKeyToAccount(config.privateKey);
  const walletClient = createWalletClient({
    account,
    transport,
    chain: { id: chainConfig.chainId },
  });
  return { publicClient, walletClient, ...chainConfig };
}

/** Обработка lock на цепи A: вызываем release на цепи B */
async function processLockFromAToB(log) {
  const dest = createChainClients(config.chainB);
  const user = log.args.user;
  const amount = log.args.amount;
  const originChainId = log.args.chainId;
  const nonce = log.args.nonce;

  await dest.walletClient.writeContract({
    address: dest.bridge,
    abi: bridgeAbi,
    functionName: "release",
    args: [user, amount, originChainId, nonce],
  });
  console.log(`Released ${amount} to ${user} on chain B (originChainId=${originChainId}, nonce=${nonce})`);
}

/** Обработка lock на цепи B: вызываем release на цепи A */
async function processLockFromBToA(log) {
  const dest = createChainClients(config.chainA);
  const user = log.args.user;
  const amount = log.args.amount;
  const originChainId = log.args.chainId;
  const nonce = log.args.nonce;

  await dest.walletClient.writeContract({
    address: dest.bridge,
    abi: bridgeAbi,
    functionName: "release",
    args: [user, amount, originChainId, nonce],
  });
  console.log(`Released ${amount} to ${user} on chain A (originChainId=${originChainId}, nonce=${nonce})`);
}

function main() {
  const chainA = createChainClients(config.chainA);
  const chainB = createChainClients(config.chainB);

  // Слушаем BridgeLock на цепи A → при событии вызываем release на цепи B
  chainA.publicClient.watchContractEvent({
    address: config.chainA.bridge,
    abi: bridgeAbi,
    eventName: "BridgeLock",
    onLogs: async (logs) => {
      for (const log of logs) {
        try {
          await processLockFromAToB(log);
        } catch (e) {
          console.error("Process A->B error:", e);
        }
      }
    },
  });

  // Слушаем BridgeLock на цепи B → при событии вызываем release на цепи A
  chainB.publicClient.watchContractEvent({
    address: config.chainB.bridge,
    abi: bridgeAbi,
    eventName: "BridgeLock",
    onLogs: async (logs) => {
      for (const log of logs) {
        try {
          await processLockFromBToA(log);
        } catch (e) {
          console.error("Process B->A error:", e);
        }
      }
    },
  });

  console.log("Relayer watching BridgeLock on both chains. Config: A", config.chainA.rpc, "B", config.chainB.rpc);
}

main();
