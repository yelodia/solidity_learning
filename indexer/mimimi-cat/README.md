# MimimiCat Subgraph

Subgraph для индексации контракта **MimimiCat** (NFT-лотерея) в сети **Sepolia**.

- **Контракт:** `0x0817f82aeB724b8000BA6c10496ADf25B1480f7F`

---

## Сущности

### Account (мутабельная)

Адрес участника и его текущее состояние.

- **id** — адрес (Bytes).
- **inBlacklist** — находится ли в чёрном списке на данный момент.
- **tokens** — текущие токены владельца (вычисляется по полю `owner` у Token).
- **mints** — история минтов этого аккаунта (вычисляется по полю `account` у Mint).

### Token (мутабельная)

Один NFT с текущим владельцем.

- **id** — уникальный идентификатор вида `{адрес контракта}-{tokenId}`.
- **tokenId** — номер токена.
- **owner** — текущий владелец (Account).

### Mint (иммутабельная)

Один факт минта (платный или бесплатный).

- **id**, **to** — получатель (адрес).
- **account** — связь с Account получателя.
- **tokenId** — номер заминтированного токена.
- **freeMint** — `true` для бесплатного (вайтлист), `false` для платного.
- **blockNumber**, **blockTimestamp**, **transactionHash** — блок и транзакция.

---

## Запросы (GraphQL)

### 1. Все токены, которыми владеет аккаунт на данный момент

Через **Account** и связь `tokens`:

```graphql
query TokensByOwner {
  account(id: "0xВАШ_АДРЕС_В_LOWERCASE") {
    id
    tokens {
      id
      tokenId
      owner {
        id
      }
    }
  }
}
```

Или через список **Token** с фильтром по владельцу:

```graphql
query TokensByOwnerFilter {
  tokens(where: { owner: "0xВАШ_АДРЕС_В_LOWERCASE" }) {
    id
    tokenId
    owner {
      id
    }
  }
}
```

### 2. Все пользователи в чёрном списке на данный момент

```graphql
query BlacklistedAccounts {
  accounts(where: { inBlacklist: true }) {
    id
  }
}
```

### 3. История минтов (платные и бесплатные)

Последние 100 минтов по времени:

```graphql
query MintHistory {
  mints(
    first: 100
    orderBy: blockTimestamp
    orderDirection: desc
  ) {
    id
    account {
      id
    }
    tokenId
    freeMint
    blockTimestamp
    transactionHash
  }
}
```

Только минты конкретного аккаунта:

```graphql
query MintsByAccount {
  mints(
    first: 100
    orderBy: blockTimestamp
    orderDirection: desc
    where: { account: "0xАДРЕС_АККАУНТА_В_LOWERCASE" }
  ) {
    id
    tokenId
    freeMint
    blockTimestamp
    transactionHash
  }
}
```

### 4. Минты по признаку платный / бесплатный

Только **платные** минты:

```graphql
query PaidMints {
  mints(
    first: 100
    orderBy: blockTimestamp
    orderDirection: desc
    where: { freeMint: false }
  ) {
    id
    account {
      id
    }
    tokenId
    blockTimestamp
    transactionHash
  }
}
```

Только **бесплатные** минты (вайтлист):

```graphql
query FreeMints {
  mints(
    first: 100
    orderBy: blockTimestamp
    orderDirection: desc
    where: { freeMint: true }
  ) {
    id
    account {
      id
    }
    tokenId
    blockTimestamp
    transactionHash
  }
}
```
