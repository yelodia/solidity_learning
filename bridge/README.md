# Bridge (Polygon Amoy ↔ BSC Testnet)

Двунапрвленный мост. Можно переводить токены в любом направлении

---

## 1. Деплой на обеих сетях

- **Polygon Amoy** (chainId 80002): скрипт `forge_script/DeployBridgeAmoy.s.sol` — токен с supply 10_000 YEL, мост с `remoteChainId = 97` (BSC).
- **BSC Testnet** (chainId 97): скрипт `forge_script/DeployBridgeBsc.s.sol` — токен с supply 0, мост с `remoteChainId = 80002` (Amoy).

---

## 2. Настроить релейер (.env)

В корне проекта создать `.env`:

```env
# Цепь A (Amoy — источник для lock)
CHAIN_A_RPC=https://rpc-amoy.polygon.technology
CHAIN_A_ID=80002
BRIDGE_A_ADDRESS=0x...

# Цепь B (BSC — приём release)
CHAIN_B_RPC=https://bsc-testnet-dataseed.bnbchain.org
CHAIN_B_ID=97
BRIDGE_B_ADDRESS=0x...

# Ключ кошелька релейера
PRIVATE_KEY=0x...
```

---

## 3. Lock на исходной цепи (пользователь)

Скрипт делает `approve` + `bridge.lock(amount)` на цепи A. Конфиг сетей берётся из того же `.env` (CHAIN_A_*, BRIDGE_A_ADDRESS).

```bash
node bridge/lock.js <privateKey> <amountInEther>
```

Пример (перевод 100 YEL с Amoy):

```bash
node bridge/lock.js 0x... 100
```

У пользователя должны быть YEL и нативная монета исходной цепи (для газа).

---

## 4. Запустить релейер

Релейер слушает событие `BridgeLock` на обеих цепях и вызывает `release(to, amount, originChainId, nonce)` на противоположной.

```bash
node bridge/index.js
```

Кошелёк релейера (`PRIVATE_KEY`) должен иметь нативную монету на **целевой** цепи (например BNB на BSC) для оплаты газа за `release`.

---

## 5. Результат

- На исходной цепи: баланс пользователя и totalSupply токена уменьшились (токены сожжены).
- На целевой цепи: у того же `user` появился баланс YEL в сумме `amount`.

Без запущенного релейера токены останутся залочены на исходной цепи до тех пор, пока кто-то не вызовет `release` на целевой.
