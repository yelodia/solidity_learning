/*global process*/

require("hardhat-contract-sizer");
require('hardhat-storage-layout');
require("hardhat-deploy");
require("hardhat-deploy-ethers");
require("hardhat-gas-reporter");
require("@nomicfoundation/hardhat-chai-matchers");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
require("@nomicfoundation/hardhat-toolbox");
require('dotenv').config();


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

module.exports = {
    networks: {
        local: {
            url: "http://localhost:8545",
        },
        hardhat: {
            allowUnlimitedContractSize: true,
            accounts: accounts,
        },
        sepolia: {
            url: "https://sepolia.infura.io/v3/" + INFURA_API_KEY_SEPOLIA,
            accounts: [PRIVATE_KEY],
            chainId: 11155111,
        },
    },
    etherscan: {
        customChains: [
            {
                network: "polygonAmoy",
                chainId: 80002,
                urls: {
                    apiURL: "https://api-amoy.polygonscan.com/api",
                    browserURL: "https://amoy.polygonscan.com/"
                }
            },
        ],
        apiKey: {
            mainnet: ETHERSCAN_API_KEY,
            sepolia: ETHERSCAN_API_KEY,        }
    },
    solidity: {
        compilers: [
            {
                version: "0.8.28",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 1000000,
                    },
                    evmVersion: "cancun"
                },
            }
        ]
    },
    gasReporter: {
        enabled: false
    }
};