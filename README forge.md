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