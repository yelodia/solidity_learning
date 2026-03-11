# Mythril — отдельное виртуальное окружение

Mythril установлен в **отдельном** venv (`.venv_mythril`), чтобы не конфликтовать с Slither и web3 по версиям пакетов `eth-*`.

## Запуск Mythril

Всегда используйте интерпретатор из `.venv_mythril`:
```bash
source .venv_mythril/bin/activate
myth version
myth analyze contracts/homework_3/NativeBank.sol --solc-args "--evm-version shanghai"
# или можно предварительно собрать байт-код контракта в файл:
myth analyze -f docs/nativebank_bytecode.txt --bin-runtime --execution-timeout 120
deactivate
```
Увеличение `--execution-timeout` даёт более полный символьный анализ, но увеличивает время выполнения.

## Slither

Slither по-прежнему запускается из основного venv (`.venv`):

```bash
source .venv/bin/activate
slither contracts/homework_3/NativeBank.sol --compile-force-framework foundry
```

Таким образом, оба анализатора доступны без конфликтов зависимостей.
