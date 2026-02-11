# Interactive

Взаимодействие с MimimiCat (Sepolia) через viem.

Контракт: `0x0817f82aeB724b8000BA6c10496ADf25B1480f7F`

RPC из `.env`: `SEPOLIA_RPC`.

## Скрипт 1: mint

Приватный ключ только аргументом:

```bash
npm run mint -- --private-key=0x...
```

Вывод: баланс, хеш транзакции, estimateGas, receipt, статус, фактический затраченный газ. Перед выполнением транзакции запрашивает баланс на кошельке.

## Скрипт 2: read (чтение контракта)

Опционально передаётся id токена. Выводит name, symbol, state, MAX_SUPPLY, mintPrice, multiSigner, whiteList. Если передан tokenId — также tokenURI и ownerOf.

```bash
npm run read
npm run read -- 1
npm run read -- --token-id=1
```
