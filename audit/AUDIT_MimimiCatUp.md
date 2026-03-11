# Отчёт по аудиту безопасности: MimimiCatUp

**Проект:** Solidity Learning (homework_4)  
**Контракт:** MimimiCatUp (обновляемый NFT / лотерея)  
**Дата аудита:** 2026  
**Область:** Обновляемая реализация и прокси; наследуемые базовые контракты.

---

## 1. Scope (область аудита)

| Файл | Описание |
|------|-------------|
| `contracts/homework_4/upgradeable/mimimiCatUpgradeable.sol` | Основная реализация: MimimiCatUp, логика обновления |
| `contracts/homework_4/upgradeable/mimimiCatProxy.sol` | Прокси: delegatecall к реализации, слот storage для адреса реализации |
| `contracts/homework_4/initializeable/lotteryInitializeable.sol` | Логика лотереи: mint, whitelist, состояния, withdraw, close |
| `contracts/homework_4/initializeable/permissionsInitializeable.sol` | EIP-712: domain separator, nonces, проверка подписей |
| `contracts/homework_4/initializeable/roleControlInitializeable.sol` | Роли (MODERATOR, STAKEHOLDER), multisigner, owner |

**Компилятор:** Solidity 0.8.28 (Foundry).  
**Зависимости:** OpenZeppelin contracts-upgradeable (ERC721, AccessControl), OpenZeppelin contracts (MerkleProof, MessageHashUtils, Strings).

---

## 2. Executive Summary (краткое резюме)

MimimiCatUp — обновляемый ERC721-контракт лотереи с платным минтом, подписанным минтом, бесплатным минтом (whitelist) и фазой закрытия, в которой стейкхолдеры могут выводить баланс контракта, а мультиподписант получает фиксированную награду. Реализация используется за кастомным прокси, хранящим адрес реализации в выделенном слоте storage. Критических и высоких по severity проблем не выявлено. Находки низкие и информационные (события, проверка нулевого адреса, замечания по реентрантности, газ, именование). Обновляемость реализована через фиксированный слот storage для реализации; при будущих реализациях нужно учитывать расклад storage. В автоматической проверке использованы Slither и Mythril (символьный анализ по bytecode реализации); срабатывания Mythril SWC-101 признаны ложными для Solidity 0.8.x (см. раздел 3.2).

| Severity | Количество |
|----------|--------|
| Критический | 0 |
| Высокий   | 0 |
| Средний   | 0 |
| Низкий    | 2 |
| Информационный | 6 |

---

## 3. Методология и автоматический анализ

Использованы статический анализ (Slither) и символьное выполнение (Mythril по bytecode). Ручная проверка — векторы атак (реентрантность, контроль доступа, подписи, конечный автомат), оптимизация газа, обновляемость (прокси, storage, инициализация).

### 3.1 Slither

Slither запускался с Foundry в качестве фреймворка сборки:

```bash
slither contracts/homework_4/upgradeable/mimimiCatUpgradeable.sol --compile-force-framework foundry
```

**Сводка по находкам (только код проекта; node_modules исключён):**

- **arbitrary-send-eth:** `LotteryInitializeable.withdraw` и `signedClose` отправляют ETH на `msg.sender`. По задумке (onlyRole(ROLE_STAKEHOLDER) и onlyMultisigner/подписанное закрытие). Уязвимостью не является при контроле доступа и состоянии CLOSE перед withdraw.
- **shadowing-local:** Параметры с именем `_owner` в LotteryInitializeable (например в `lotteryInit`, `signedMint`, `permit`) затеняют переменную состояния `_owner` в RoleControlInitializeable. Функциональной ошибки нет; можно избежать путаницы, переименовав параметры.
- **events-access:** В `RoleControlInitializeable.setMultiSigner` обновляется `multiSigner` без эмита события. Для оффчейн-индексации и прозрачности полезно событие (Low/Информационный).
- **missing-zero-check:** В `RoleControlInitializeable.setMultiSigner(address _signer)` нет проверки `_signer != address(0)`. Установка multisigner в ноль может сломать `signedClose` и другие функции только для multisigner (Low).
- **assembly:** В `MimimiCatUp.changeImplementation` используется inline assembly для записи адреса реализации в слот storage прокси. Намеренно и необходимо для паттерна обновления; нужно следить, чтобы слот не пересекался с раскладом реализации.
- **low-level-calls:** В `LotteryInitializeable.withdraw` и `signedClose` используется `call{value:}`. Документировано; при ошибке — revert. Допустимо.
- **naming-convention:** Ряд параметров и внутренних имён не в mixedCase/UPPER_CASE по Slither. Информационно.

В `node_modules` (в т.ч. OpenZeppelin Math, Strings, ERC721) Slither также выдал много предупреждений; они выходят за рамки данного аудита.

### 3.2 Mythril

Mythril запускался в отдельном виртуальном окружении (`.venv_mythril`), см. `MYTHRIL_README.md`. Анализ выполнялся по runtime-bytecode реализации (файл `mimimicatup_bytecode.txt`, получен из артефактов Forge после `forge build`).

**Команда запуска:**
```bash
myth analyze -f audit/mimimicatup_bytecode.txt --bin-runtime --execution-timeout 120
```

**Результаты прогона:** Mythril успешно выполнил символьный анализ. Обнаружено **19 предупреждений** типа Integer Arithmetic Bugs (SWC-101), Severity High — арифметика в различных функциях/геттерах: state(), owner(), balanceOf(address), mintPrice(), blackList(address), whiteList(), MAX_SUPPLY(), supportsInterface(bytes4), setApprovalForAll(address,bool) и ряд функций по селекторам (_function_0x...).

**Интерпретация (ложные срабатывания):** Реализация MimimiCatUp и наследуемые контракты собраны под **Solidity 0.8.28**. В Solidity 0.8+ арифметика проверяемая; при переполнении/underflow выполняется revert. Mythril анализирует только байткод и не учитывает защиту компилятора. Все срабатывания SWC-101 для данного контракта **не применимы** и считаются ложными срабатываниями. Дополнительных действий не требуется.

**Полный вывод Mythril:** [mythril_mimimiCatUp.txt](mythril_mimimiCatUp.txt)

---

## 4. Векторы атак и ручная проверка

### 4.1 Реентрантность

- **withdraw (LotteryInitializeable):** Вызывается только при `state == STATE_CLOSE` и только с ролью ROLE_STAKEHOLDER. Отправляет ETH на `msg.sender`. После `call` состояние не меняется; основной риск — повторный вход в тот же контракт. Вредоносный стейкхолдер может реентрантно войти до выхода из функции, но выгодного состояния для эксплуатации нет (баланс не уменьшается до отправки так, чтобы допустить двойной вывод). Риск **низкий**; при желании можно добавить nonReentrant для усиления защиты.
- **signedClose:** Состояние и baseURI обновляются в `_close`, затем отправляется REWARD_FOR_CLOSE на `msg.sender`. К моменту отправки состояние уже CLOSE. Повторный вход не сбросит состояние. Риск низкий.
- **Пути mint:** ETH приходит через `msg.value`, состояние (tokenIdCounter, whiteListSupply, whiteListMinted) обновляется до внешнего вызова к получателю. ERC721 `_mint` может вызывать колбэки; контракт в этом потоке ETH не отправляет. Критической реентрантности не выявлено.

### 4.2 Контроль доступа

- **Owner:** Задаётся в `roleControlInit` (при `lotteryInit`). Только владелец может добавлять/удалять модераторов и стейкхолдеров, задавать multisigner и в MimimiCatUp вызывать `changeImplementation`.
- **Роли:** MODERATOR (setState, setToBlackList), STAKEHOLDER (setMintPrice, withdraw при закрытии), multisigner (setWhiteList, close, signedClose). Обеспечивается модификаторами.
- **changeImplementation:** Только owner; в реализации проверяется нулевой адрес. В конструкторе прокси также проверяются implementation != 0 и data.length != 0.

Ошибок контроля доступа в проверенном коде не выявлено.

### 4.3 Подписи и повторное использование (replay)

- **EIP-712:** В domainSeparator входят name, version, chainId, verifyingContract. В permit и подписанных mint/free mint/close используются nonces. Повтор между цепями ограничен chainId; в одной цепи — nonces (инкремент при использовании). Дизайн корректен.
- **verifyingContract:** В контексте delegatecall `address(this)` — адрес прокси, поэтому подписи привязаны к прокси. Для обновляемого паттерна верно.

### 4.4 Конечный автомат и логика

- **Состояния:** PAUSE, OPEN, CLOSE. setState не допускает прямого перехода в CLOSE (нужны close/signedClose). close/signedClose устанавливают CLOSE и (для signedClose) выплачивают награду. Withdraw только при CLOSE. Согласовано.
- **Supply и whitelist:** tokenIdCounter и whiteListSupply ограничивают минты; whiteListMinted предотвращает двойной бесплатный минт. Blacklist блокирует минт. Явного переполнения при нормальном использовании нет (Solidity 0.8); MAX_SUPPLY immutable.

---

## 5. Анализ газа

Разбор расхода газа по горячим путям и storage в контрактах цепочки MimimiCatUp (LotteryInitializeable, RoleControlInitializeable, PermissionsInitializeable).

### 5.1 Горячие пути: mint и withdraw

- **mint() / _mintMCT():**
  - Чтения: `state`, `blackList[_account]`, `mintPrice`, `whiteListSupply`, `tokenIdCounter`, лимит в mintEnabled. Несколько SLOAD; при повторных вызовах часть будет warm (100 газа). Кэширование `state` и лимита в локальные переменные при сложной логике уменьшает повторные чтения.
  - Запись: `tokenIdCounter++` в mintEnabled уже в unchecked; плюс наследуемый _mint (storage ERC721). Затраты в основном от ERC721 и эмита событий.
- **withdraw() (при state == CLOSE):**
  - Чтение роли и состояния, затем `msg.sender.call{value: _amount}`. Основная стоимость — внешний вызов и передача ETH; storage-операций мало.
- **signedClose() / _close():**
  - Обновление `state`, `baseURI`, затем вызов с REWARD_FOR_CLOSE. Два SSTORE и один CALL доминируют в стоимости.

### 5.2 Storage: расклад и упаковка

- **LotteryInitializeable:** state (uint8), MAX_SUPPLY (uint32), whiteListSupply (uint32), tokenIdCounter (uint32), mintPrice (uint256), baseURI (string), whiteList (bytes32), затем mappings. Четыре коротких типа (uint8, uint32×3) теоретически упаковываются в один-два слота; из-за наследования и порядка полей в родителях (ERC721, AccessControl, Permissions) итоговый расклад задаётся цепочкой наследования. Менять порядок в дочернем контракте нужно с учётом совместимости при апгрейде (не сдвигать существующие слоты).
- **RoleControlInitializeable:** multiSigner (address), _owner (address) — два адреса в двух слотах. Упаковка с uint8/uint16 возможна только если добавить такие поля и не ломать layout.
- **PermissionsInitializeable:** строки pVersion, pName (динамические) и mapping nonces. Строки не упаковываются; оптимизация — только при рефакторинге (например, короткие байты вместо string).

### 5.3 Константы и immutable

- **MAX_SUPPLY**, **STATE_***, **REWARD_FOR_CLOSE** уже объявлены как constant/immutable — чтения не дают SLOAD, экономия на каждом обращении к лимитам и состоянию.
- **multiSigner** и **_owner** меняются при админ-операциях; делать их immutable нельзя. Оставлять как есть.

### 5.4 Циклы и массивы

- **addModerators / removeModerators / addStakeHolders / removeStakeHolders:** параметр `address[] calldata`, в цикле используется кэш `len = _accounts.length` — повторного чтения длины нет. Внутри цикла вызовы _grantRole/_revokeRole (наследуемый storage AccessControl); основная стоимость — запись в storage ролей, не массив.
- **LotteryInitializeable:** в горячих путях (mint, freeMint) массивов в storage по индексу в цикле нет; tokenIdCounter и whiteListSupply — одиночные счётчики, инкремент/декремент уже в unchecked.

### 5.5 Unchecked и арифметика

- **PermissionsInitializeable:** в _validatePermit, _validateMint, _validateFreeMint используется unchecked с nonces[_owner]++; replay защищён инкрементом nonce — переполнение нереалистично.
- **LotteryInitializeable:** в mintEnabled блок unchecked с tokenIdCounter++ и --whiteListSupply; верхняя граница задаётся MAX_SUPPLY и начальным whiteListSupply. Дополнительные блоки unchecked в других местах возможны только после явной проверки границ (например, арифметика после require).

При любых изменениях расклада storage (упаковка, порядок полей) необходимо проверять совместимость с прокси и с будущими версиями реализации.

---

## 6. Обновляемость (Upgradeability)

### 6.1 Прокси (MimimiCatProxy)

- **Storage:** Адрес реализации хранится в слоте по константе `MIMIMICAT_STORAGE`. Fallback передаёт все вызовы этой реализации через delegatecall. В конструкторе проверяются implementation != 0 и data.length != 0 и выполняется один delegatecall для инициализации.
- **receive:** Делает revert; предотвращает случайную отправку ETH на прокси без calldata. Допустимо.
- **getImplementation:** Только чтение; полезно для верификации.

### 6.2 changeImplementation (MimimiCatUp)

- **Доступ:** onlyOwner. Только владелец может переключить прокси на новую реализацию.
- **Проверка нуля:** Revert при newImplementation == address(0). Хорошо.
- **Запись в storage:** В assembly записывается новая реализация в тот же слот, что использует прокси. При выполнении в контексте прокси (через delegatecall) обновляется storage прокси. Корректно.
- **permissionsInit(name(), _version):** Вызывается после записи слота. Обновляет name/version EIP-712 в storage прокси. Нужно для версионирования после апгрейда; важно, чтобы новая реализация это учитывала (критическое состояние не перезаписывается). Критической проблемы не выявлено; стоит задокументировать для будущих реализаций.

### 6.3 Расклад storage

- Переменные состояния контракта реализации используют storage прокси (delegatecall). Прокси использует один выделенный слот для адреса реализации. Этот слот не занят объявленными переменными реализации (они начинаются с слота 0 в раскладе реализации, что соответствует слоту 0 прокси). Реализация пишет в слот реализации только в changeImplementation; с обычным состоянием пересечения нет. **Вывод:** Расклад storage для текущего паттерна безопасен. Новые реализации должны сохранять тот же расклад или использовать унаследованный storage и только добавлять переменные.

### 6.4 Инициализация

- **initialize:** Защищён модификатором initializer из OpenZeppelin (однократный вызов). Вызывается lotteryInit, задающий роли и права. Логика конструктора в контексте прокси не выполняется (только при деплое контракта реализации). **Вывод:** Инициализация устроена корректно; двойной инициализации и выполнения конструктора в прокси не выявлено.

### 6.5 Риски, связанные с обновлением

- **Централизация:** Владелец может заменить реализацию. Это принимаемый риск паттерна обновления. Критической проблемы нет при доверии к владельцу.
- **Совместимость:** Будущие реализации должны сохранять совместимость расклада storage или использовать паттерны расширения (например namespaced storage). Рекомендуется документировать для последующих апгрейдов.

---

## 7. Findings (находки)

| ID | Severity | Название | Описание | Рекомендация | Статус |
|----|----------|--------|-------------|----------------|--------|
| MCT-01 | Низкий | setMultiSigner допускает нулевой адрес | setMultiSigner не делает revert при _signer == address(0). Установка multisigner в ноль может сломать signedClose и другие функции только для multisigner. | Добавить Require(_signer != address(0)) в setMultiSigner. | Open |
| MCT-02 | Низкий | Нет события в setMultiSigner | Изменения multiSigner не эмитятся. | Эмитить событие (например MultiSignerUpdated) для индексации и прозрачности. | Open |
| MCT-03 | Информационный | Реентрантность в withdraw/signedClose | Slither помечает произвольную отправку; ручная проверка показывает низкое влияние реентрантности. | По желанию добавить nonReentrant на withdraw (и при необходимости signedClose) для усиления защиты. | Open |
| MCT-04 | Информационный | Затенение параметром _owner | Локальные параметры _owner затеняют переменную состояния _owner в RoleControlInitializeable. | Переименовать параметры (например в recipient или account), чтобы избежать путаницы. | Open |
| MCT-05 | Информационный | Стиль именования | Параметры/переменные не в mixedCase по Slither. | Привести к mixedCase где уместно (стиль). | Open |
| MCT-06 | Информационный | Упаковка storage | Часть переменных состояния можно упаковать для экономии газа. | При изменении расклада сохранять совместимость при обновлении (только добавление или namespaced). | Open |
| MCT-07 | Информационный | Assembly в changeImplementation | Для записи слота обновления используется inline assembly. | Оставить как есть; задокументировать слот и расклад для будущих реализаций. | Open |
| MCT-08 | Информационный | Mythril SWC-101 | Mythril сообщает о 19 срабатываниях Integer Arithmetic Bugs (SWC-101) по bytecode. | Не применимо: контракт на Solidity 0.8.x с проверяемой арифметикой; срабатывания — ложные. Вывод: [mythril_mimimiCatUp.txt](mythril_mimimiCatUp.txt). | Acknowledged |

---

## 8. Выводы и рекомендации

- **Безопасность:** Критических и высоких по severity проблем нет. Контроль доступа и дизайн подписей выглядят корректно. Паттерн обновления (прокси + один слот + changeImplementation) реализован правильно; расклад storage и инициализация не вносят критических проблем при обновлении.
- **Рекомендации:** (1) Добавить проверку нулевого адреса и событие в setMultiSigner (MCT-01, MCT-02). (2) По желанию добавить nonReentrant на withdraw/signedClose (MCT-03). (3) Применить информационные пункты по необходимости (именование, упаковка с учётом расклада). (4) Задокументировать расклад storage и правила обновления для будущих реализаций. (5) Результаты Mythril учтены (раздел 3.2, [mythril_mimimiCatUp.txt](mythril_mimimiCatUp.txt)); срабатывания SWC-101 признаны ложными.

---

## 9. Приложение — вывод Slither (MimimiCatUp, только код проекта)

Релевантные находки Slither по контрактам проекта (node_modules исключён):

```
Detector: arbitrary-send-eth
LotteryInitializeable.withdraw(uint256) ... sends eth to arbitrary user
LotteryInitializeable.signedClose(string,uint8,bytes32,bytes32) ... sends eth to arbitrary user

Detector: shadowing-local
LotteryInitializeable.lotteryInit(..., address _owner) shadows RoleControlInitializeable._owner
LotteryInitializeable.signedMint(address _owner, ...) shadows ...
LotteryInitializeable.signedFreeMint(address _owner, ...) shadows ...
LotteryInitializeable.permit(address _owner, ...) shadows ...

Detector: events-access
RoleControlInitializeable.setMultiSigner(address) should emit an event for: multiSigner = _signer

Detector: missing-zero-check
RoleControlInitializeable.setMultiSigner(address _signer) lacks a zero-check on multiSigner = _signer

Detector: assembly
MimimiCatUp.changeImplementation(address,string) uses assembly (INLINE ASM for sstore)

Detector: low-level-calls
LotteryInitializeable.withdraw ... call{value: _amount}()
LotteryInitializeable.signedClose ... call{value: REWARD_FOR_CLOSE}()

Detector: naming-convention
(Различные параметры и переменные не в mixedCase/UPPER_CASE в файлах проекта)

INFO:Slither: contracts/homework_4/upgradeable/mimimiCatUpgradeable.sol analyzed (26 contracts with 101 detectors), 101 result(s) found
```

Примечание: полный прогон содержит много предупреждений в node_modules (OpenZeppelin); выше приведены только относящиеся к проекту.

**Mythril:** Результаты и интерпретация — в разделе 3.2. Полный вывод: [mythril_mimimiCatUp.txt](mythril_mimimiCatUp.txt).
