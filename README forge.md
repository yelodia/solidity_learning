## Usage

### Running Tests

All tests
```shell
forge test
```

One file
```shell
forge test --match-path test/NativeBank.t.sol
```

One contract
```shell
forge test --match-contract NativeBankTest
```

One test
```shell
forge test --match-test testDeposit
```

Combo
```shell
forge test --match-contract NativeBankTest --match-test testDeposit
```

Add `--gas-report` flag to `forge test` command to view gas report

### Storage layout

Make build first:
```shell
forge build
```

Console output:
```shell
forge inspect contracts/homework_3/NativeBankOpt.sol:NativeBankOpt storage
```
```shell
forge inspect NativeBankOpt storage
```

JSON output:
```shell
cat artifacts_forge/NativeBank.sol/NativeBank.json | jq .storageLayout > storage-layout.json
```

### Coverage
```shell
forge coverage --match-contract NativeBank
```

### Make a deployment to Sepolia

This project includes an example Ignition module to deploy the contract. You can deploy this module to a locally simulated chain or to Sepolia.

To run the deployment to a local chain:

```shell
npx hardhat ignition deploy ignition/modules/Counter.ts
```

To run the deployment to Sepolia, you need an account with funds to send the transaction. The provided Hardhat configuration includes a Configuration Variable called `SEPOLIA_PRIVATE_KEY`, which you can use to set the private key of the account you want to use.

You can set the `SEPOLIA_PRIVATE_KEY` variable using the `hardhat-keystore` plugin or by setting it as an environment variable.

To set the `SEPOLIA_PRIVATE_KEY` config variable using `hardhat-keystore`:

```shell
npx hardhat keystore set SEPOLIA_PRIVATE_KEY
```

After setting the variable, you can run the deployment with the Sepolia network:

```shell
npx hardhat ignition deploy --network sepolia ignition/modules/Counter.ts
```

### Verify in Sepolia Etherscan
without constructor
```shell
npx hardhat verify --network sepolia 0x469...
```
with simple constructor
```shell
npx hardhat verify --network sepolia 0x469... 1000 "SomeString"
```
with constructor args path
```shell
npx hardhat verify --network sepolia 0x469... --constructor-args-path ignition/modules/Construct.js
```

### Deploy & Verification
Deploy with script
```shell
forge script forge_script/DeployNativeBankOpt.s.sol --rpc-url sepolia --broadcast
```

Verify
```shell
forge verify-contract 0x7b5133B15... NativeBankOpt --chain sepolia --constructor-args 
$(cast abi-encode "constructor(address[3])" "[0x4a8a...,0x468....,0x567...]")
```
or add `--verify` flag to deploy command