export const bridgeAbi = [
  {
    inputs: [],
    name: "token",
    outputs: [{ type: "address" }],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [{ name: "amount", type: "uint256" }],
    name: "lock",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
      { name: "originChainId", type: "uint64" },
      { name: "nonce_", type: "uint64" },
    ],
    name: "release",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    anonymous: false,
    inputs: [
      { indexed: true, name: "user", type: "address" },
      { indexed: false, name: "amount", type: "uint256" },
      { indexed: false, name: "chainId", type: "uint64" },
      { indexed: false, name: "nonce", type: "uint64" },
    ],
    name: "BridgeLock",
    type: "event",
  },
];

export const tokenApproveAbi = [
  {
    inputs: [
      { name: "spender", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    name: "approve",
    outputs: [{ type: "bool" }],
    stateMutability: "nonpayable",
    type: "function",
  },
];
