# Отчёт по аудиту безопасности: NativeBank

**Проект:** Solidity Learning (homework_3)  
**Контракт:** NativeBank  
**Дата аудита:** 2026  
**Область:** Один контракт и его интерфейс.

---

## 1. Scope (область аудита)

| Файл | Описание |
|------|-------------|
| `contracts/homework_3/NativeBank.sol` | Основной контракт: банк нативной валюты с комиссией, владельцем и тремя стейкхолдерами |
| `contracts/homework_3/INativeBank.sol` | Интерфейс (события, ошибки, сигнатуры функций) |

**Компилятор:** Solidity 0.8.28 (Foundry).  
**Зависимости:** Только интерфейс.

---

## 2. Executive Summary (краткое резюме)

Контракт NativeBank принимает депозиты в нативном ETH, взимает настраиваемую комиссию (в базисных пунктах) и зачисляет остаток на балансы пользователей. Владелец может выводить накопленные комиссии (по 1/4 владельцу и трём стейкхолдерам) и настраивать комиссию и адреса стейкхолдеров. Критических и высоких по severity проблем не выявлено. Находки в основном низкие/информационные (инструменты, именование, оптимизация газа) и одна средняя (возможный DoS, если стейкхолдер — контракт с revert при приёме ETH). Реентрантность смягчена обновлением состояния до внешних вызовов и модификатором nonReentrant на `withdraw`. В автоматической проверке использованы Slither и Mythril (символьное выполнение по исходному коду и по bytecode).

| Severity | Количество |
|----------|--------|
| Критический | 0 |
| Высокий   | 0 |
| Средний   | 1 |
| Низкий    | 2 |
| Информационный | 7 |

---

## 3. Методология и автоматический анализ

Использованы статический анализ (Slither) и символьное выполнение (Mythril). Ручная проверка — векторы атак (реентрантность, контроль доступа, арифметика, DoS), оптимизация газа, обновляемость.

### 3.1 Slither

Slither запускался с Foundry в качестве фреймворка сборки:

```bash
slither contracts/homework_3/NativeBank.sol --compile-force-framework foundry
```

**Сводка по находкам (только код проекта):**

- **arbitrary-send-eth:** `_send` переводит ETH на произвольный адрес. Это задумано (вывод пользователя и выплаты владельцу/стейкхолдерам). Уязвимостью не является при наличии контроля доступа и обновления состояния до отправки.
- **events-maths:** Рекомендуется эмитить события при `accumulator -= _amount` в `withdrawAccumulator` и при `commissionBp = _commission` в `setCommission`. Полезно для оффчейн-индексации (Low/Информационный).
- **low-level-calls:** Использование `call{value:}` в `_send`. Документировано; при ошибке — revert. Допустимо.
- **naming-convention:** Параметры не в mixedCase (например `_amount`, `_commission`, `_holders`). Информационно.
- **cache-array-length:** В цикле `i < stakeHolders.length` лучше кэшировать длину для экономии газа. Корректная оптимизация (Low).
- **constable-states:** `bps` (10000) целесообразно объявить константой. Корректно (газ / информационно).
- **immutable-states:** `owner` задаётся только в конструкторе и не меняется; можно объявить immutable. Корректно (газ / информационно).

### 3.2 Mythril

Mythril запускался в отдельном виртуальном окружении (`.venv_mythril`), см. `docs/MYTHRIL_README.md`.

**Команда запуска (по bytecode):**
```bash
myth analyze -f docs/nativebank_bytecode.txt --bin-runtime --execution-timeout 120
```

**Результаты прогона:** Mythril успешно выполнил символьный анализ runtime-bytecode контракта. Обнаружено **5 предупреждений** одного типа:

| SWC | Severity | Описание | Функция / селектор |
|-----|----------|----------|---------------------|
| 101 | High | Integer Arithmetic Bugs — возможное переполнение/underflow в арифметической операции | owner() / 0x8da5cb5b; balanceOf(address) / 0x70a08231; 0x68237329; 0x057cc53a; 0x03381154 |

**Интерпретация (ложные срабатывания):** Контракт собран компилятором **Solidity 0.8.28**. В Solidity 0.8+ вся арифметика по умолчанию **проверяемая**: при переполнении или underflow транзакция откатывается (revert). Mythril анализирует только байткод и помечает любые арифметические операции как потенциально уязвимые, не учитывая, что компилятор уже вставил проверки. Соответственно, предупреждения SWC-101 для NativeBank **не применимы** и считаются ложными срабатываниями. Дополнительных действий не требуется.

Реентрантность и неконтролируемая отправка ETH в данном прогоне Mythril не были помечены; ручная проверка этих векторов приведена в разделе 4.

**Полный вывод Mythril:** [docs/mythril_nativeBank.txt](docs/mythril_nativeBank.txt)

---

## 4. Векторы атак и ручная проверка

### 4.1 Реентрантность

- **withdraw:** Баланс уменьшается до вызова `_send` (паттерн CEI), функция защищена модификатором `nonReentrant`. Вредоносный receive/fallback у получателя не может повторно войти и снять средства снова.
- **withdrawAccumulator:** `accumulator` уменьшается до любых вызовов `_send`. Даже при реентрантности со стороны контракта стейкхолдера повторно пройти `allowWithdraw(_amount, accumulator)` на ту же сумму нельзя. Реентрантность в другие функции (например `deposit`) не даёт двойного списания. Риск: **низкий** (потери средств не выявлено).
- **deposit:** После изменения состояния внешних вызовов нет; риска реентрантности нет.

**Вывод:** Реентрантность достаточно смягчена.

### 4.2 Контроль доступа

- **owner:** Задаётся в конструкторе; функции `transferOwnership` нет. Только функции с `onlyOwner` могут менять комиссию, стейкхолдеров и выводить из accumulator. Риск централизации (единственный владелец) принимается.
- **Привилегированные функции:** `setCommission`, `setHolders`, `withdrawAccumulator` корректно ограничены `onlyOwner`.

Ошибок контроля доступа не выявлено.

### 4.3 Целочисленная арифметика и валидация входных данных

- В Solidity 0.8.x включены проверки на переполнение/underflow.
- **deposit:** Условие `(msg.value * commissionBp) < bps` при ненулевой комиссии гарантирует, что комиссия округляется минимум до 1 wei, иначе транзакция откатывается; исключается «пыль», способная нарушить учёт.
- **withdrawAccumulator:** `_part = _amount / 4`; при `_amount < 4` получается `_part == 0`, функция делает revert с `WithdrawalAmountZero`. Исключаются нулевые переводы; при amount >= 4 на долю приходится минимум 1 wei.

Проблем с целыми числами и валидацией не выявлено.

### 4.4 DoS / Griefing

- **Стейкхолдер как контракт:** Если один из `stakeHolders[i]` — контракт, который делает revert в `receive()` или `fallback()`, `withdrawAccumulator` откатится. Владелец не сможет вывести накопленные комиссии, пока список стейкхолдеров не обновят на принимающий адрес. Зафиксировано как **NB-01 (Средний)** в разделе Findings.

---

## 5. Анализ газа

Разбор расхода газа по горячим путям и storage контракта NativeBank.

### 5.1 Горячие пути: deposit, withdraw, withdrawAccumulator

- **deposit():**
  - Чтения: `commissionBp`, `bps` (два SLOAD), затем расчёт комиссии. Запись: `balanceOf[msg.sender] += _amount`, `accumulator += _fee` (два SSTORE). Арифметика `msg.value - _fee` и накопления безопасны от переполнения (0.8.x, комиссия не больше msg.value); можно обернуть в `unchecked`.
- **withdraw():**
  - Модификаторы: чтение `balanceOf[msg.sender]`, затем `lock` (SLOAD), запись `lock = 1`, после вызова `_send` — запись `balanceOf[msg.sender] -= _amount` и `lock = 0`. Вычитание баланса защищено `allowWithdraw`; допустим `unchecked`. Основная стоимость — внешний CALL при `_send`.
- **withdrawAccumulator():**
  - Чтения: `accumulator`, затем в цикле `stakeHolders.length` (SLOAD на каждой итерации) и `stakeHolders[i]` (SLOAD по индексу). Запись: `accumulator -= _amount`; затем четыре CALL. Критично: кэшировать длину массива и заменить массив на mapping (см. 5.4) снижает количество SLOAD.

### 5.2 Упаковка storage

- **Текущий расклад (упрощённо):** `commissionBp` (uint16), `accumulator` (uint256), `bps` (uint16), `owner` (address), `balanceOf` (mapping), `stakeHolders` (динамический массив), `lock` (uint8).
- **Наблюдение:** `commissionBp` и `bps` можно разместить в одном 32-байтном слоте (два uint16). `lock` — один байт, можно объединить с другими короткими типами в отдельном слоте. Переупорядочивание и упаковка снижают затраты на деплой и чтение.

### 5.3 Константы и immutability

- **bps:** Всегда 10000; после деплоя не перезаписывается. Объявление как `constant` уберёт SLOAD и уменьшит размер деплоя.
- **owner:** Задаётся только в конструкторе и не меняется. Объявление как `immutable` сэкономит storage и снизит стоимость чтения в `onlyOwner`.

### 5.4 Структуры данных

- **stakeHolders:** Реализован как `address[]` с `push` в конструкторе и циклом `for (i < stakeHolders.length)` в `withdrawAccumulator`. Размер фиксирован (3). Замена на `mapping(uint8 => address)` избавляет от динамического массива и повторного SLOAD длины в цикле и снижает расход газа (см. NB-10).

### 5.5 Использование unchecked

- **deposit:** Выражения `_amount = msg.value - _fee`, `balanceOf[msg.sender] += _amount`, `accumulator += _fee` при инвариантах контракта не переполняются. Обёртка в `unchecked` даёт экономию газа.
- **withdraw:** `balanceOf[msg.sender] -= _amount` защищён `allowWithdraw`. Допустим `unchecked`.
- **withdrawAccumulator:** `accumulator -= _amount` защищён `allowWithdraw`. Аналогично.

---

## 6. Обновляемость (Upgradeability)

**Не применимо.** NativeBank не обновляемый: нет прокси, delegatecall и механизма замены логики или storage. Вся логика и состояние в одном развёрнутом контракте. Риски, связанные с обновлением, отсутствуют.

---

## 7. Findings (находки)

| ID | Severity | Название | Описание | Рекомендация | Статус |
|----|----------|--------|-------------|----------------|--------|
| NB-01 | Средний | DoS при отказе стейкхолдера от приёма ETH | Если один из `stakeHolders[i]` — контракт с revert при приёме ETH, `withdrawAccumulator` откатится и владелец не сможет вывести накопленные комиссии. | Задокументировать, что стейкхолдеры должны быть EOA или контрактами, принимающими ETH; либо добавить возможность пропустить/заменить получателя (например pull-паттерн или замена стейкхолдера). | Open |
| NB-02 | Низкий | Нет событий при изменении важного состояния | Нет событий при уменьшении `accumulator` и смене `commissionBp`. | Эмитить события в `withdrawAccumulator` и `setCommission` для оффчейн-индексации и прозрачности. | Open |
| NB-03 | Низкий | Кэшировать длину массива в цикле | В `withdrawAccumulator` в условии цикла используется `stakeHolders.length`. | Кэшировать `uint256 len = stakeHolders.length` перед циклом, чтобы не читать длину из storage повторно. | Open |
| NB-04 | Информационный | bps как константа | `bps` не изменяется. | Объявить как `constant` для экономии storage и газа. | Open |
| NB-05 | Информационный | owner как immutable | `owner` задаётся только в конструкторе. | Объявить как `immutable` для экономии storage и газа. | Open |
| NB-06 | Информационный | Упаковка storage | Короткие типы можно упаковать в меньше слотов. | Сгруппировать uint16/uint8 и переупорядочить переменные состояния. | Open |
| NB-07 | Информационный | Стиль именования | Slither указывает на параметры не в mixedCase. | Привести именование параметров к mixedCase (стиль). | Open |
| NB-08 | Информационный | Блоки unchecked | Ряд арифметических операций безопасны в плане переполнения/underflow. | Использовать `unchecked` для отмеченных мест после проверки. | Open |
| NB-09 | Информационный | Mythril SWC-101 | Mythril сообщает о 5 срабатываниях Integer Arithmetic Bugs (SWC-101) по bytecode. | Не применимо: контракт на Solidity 0.8.x с проверяемой арифметикой; срабатывания — ложные. | Acknowledged |
| NB-10 | Информационный | Массив вместо mapping | `stakeHolders` реализован как `address[]`; в цикле в `withdrawAccumulator` читается `stakeHolders.length`. | Заменить на `mapping(uint8 => address)` (индексы 0, 1, 2): экономия газа при деплое и при выводе комиссий, нет повторного sload длины. | Open |

---

## 8. Выводы и рекомендации

- **Безопасность:** Критических и высоких по severity проблем нет. Реентрантность смягчена; контроль доступа соответствует модели с одним владельцем. Основной операционный риск — DoS в `withdrawAccumulator`, если стейкхолдер не может принять ETH (NB-01).
- **Рекомендации:** (1) Принять NB-01 как риск или смягчить (документация или изменение дизайна). (2) По возможности применить низкие и информационные находки (события, constant/immutable, кэш длины, упаковка, unchecked). (3) **Массив стейкхолдеров:** заменить `address[] stakeHolders` на mapping с фиксированным набором индексов (например `mapping(uint8 => address)`) — это устранит динамический массив, избавит от чтения `.length` в цикле в `withdrawAccumulator` и снизит расход газа при деплое и при снятии комиссий. (4) Результаты Mythril учтены (раздел 3.2); срабатывания SWC-101 признаны ложными для Solidity 0.8.x.

---

## 9. Приложение — вывод Slither (NativeBank)

Сырой вывод Slither для `contracts/homework_3/NativeBank.sol` (только находки по проекту):

```
Detector: arbitrary-send-eth
NativeBank._send(uint256,address) (contracts/homework_3/NativeBank.sol#78-83) sends eth to arbitrary user
	Dangerous calls:
	- (success,None) = _account.call{value: _amount}() (contracts/homework_3/NativeBank.sol#79)

Detector: events-maths
NativeBank.withdrawAccumulator(uint256) ... should emit an event for: accumulator -= _amount
NativeBank.setCommission(uint16) ... should emit an event for: commissionBp = _commission

Detector: low-level-calls
Low level call in NativeBank._send(uint256,address) ...

Detector: naming-convention
Parameter NativeBank.withdraw(uint256)._amount ... Parameter NativeBank.setHolders(address[3])._holders ... (not in mixedCase)

Detector: cache-array-length
Loop condition i < stakeHolders.length ... should use cached array length

Detector: constable-states
NativeBank.bps ... should be constant

Detector: immutable-states
NativeBank.owner ... should be immutable

INFO:Slither: ... NativeBank.sol analyzed (2 contracts with 101 detectors), 11 result(s) found
```

**Mythril:** Результаты и интерпретация — в разделе 3.2. Полный вывод: [docs/mythril_nativeBank.txt](docs/mythril_nativeBank.txt).
