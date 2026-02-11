import type { HardhatUserConfig } from "hardhat/config";

import hardhatToolboxMochaEthersPlugin from "@nomicfoundation/hardhat-toolbox-mocha-ethers";
import hardhatStorageLayoutInspector from '@solidstate/hardhat-storage-layout-inspector';
import { config as dotEnvConfig } from "dotenv";
dotEnvConfig();

const INFURA_API_KEY_SEPOLIA = process.env.INFURA_API_KEY_SEPOLIA;
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY;
let TEST_MNEMONIC = process.env.TEST_MNEMONIC;

const accounts = {
  mnemonic: TEST_MNEMONIC,
  path: "m/44'/60'/0'/0",
  initialIndex: 0,
  count: 100,
  accountsBalance: "10000000000000000000000"
};

const config: HardhatUserConfig = {
  plugins: [hardhatToolboxMochaEthersPlugin, hardhatStorageLayoutInspector],
  
  networks: {
    hardhat: {
      type: "edr-simulated",
      chainId: 31337,
      accounts: accounts,
    },
    sepolia: {
        type: "http",
        chainType: "l1",
        url: "https://sepolia.infura.io/v3/" + INFURA_API_KEY_SEPOLIA,
        accounts: [PRIVATE_KEY!],
        chainId: 11155111,
    },
  },

  verify: {
    etherscan: {
      enabled:  true,
      apiKey: ETHERSCAN_API_KEY!,
    },
  },

  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
};

export default config;
