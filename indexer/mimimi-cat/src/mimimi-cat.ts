import { Address } from "@graphprotocol/graph-ts"
import {
  BlacklistUpdated as BlacklistUpdatedEvent,
  Mint as MintEvent,
  Transfer as TransferEvent
} from "../generated/MimimiCat/MimimiCat"
import {
  Account,
  BlacklistUpdated,
  Mint,
  Token,
  Transfer
} from "../generated/schema"

export function handleBlacklistUpdated(event: BlacklistUpdatedEvent): void {
  let account = Account.load(event.params.account)
  if (!account) {
    account = new Account(event.params.account)
    account.inBlacklist = false
  }
  account.inBlacklist = event.params.value
  account.save()

  let entity = new BlacklistUpdated(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.account = event.params.account
  entity.value = event.params.value

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

export function handleMint(event: MintEvent): void {
  let account = Account.load(event.params.to)
  if (!account) return

  let entity = new Mint(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.to = event.params.to
  entity.account = account.id
  entity.tokenId = event.params.tokenId
  entity.freeMint = event.params.freeMint

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}

function getOrCreateAccount(address: Address): Account {
  let account = Account.load(address)
  if (!account) {
    account = new Account(address)
    account.inBlacklist = false
    account.save()
  }
  return account
}

export function handleTransfer(event: TransferEvent): void {
  let from = event.params.from
  let to = event.params.to
  let toAccount = getOrCreateAccount(to)

  if (from != Address.zero()) {
    getOrCreateAccount(from)
  }

  let tokenId = event.params.tokenId
  let tokenIdStr = event.address.toHexString() + "-" + tokenId.toString()

  if (from == Address.zero()) {
    let token = new Token(tokenIdStr)
    token.tokenId = tokenId
    token.owner = toAccount.id
    token.save()
  } else {
    let token = Token.load(tokenIdStr)
    if (token) {
      token.owner = toAccount.id
      token.save()
    }
  }

  let entity = new Transfer(
    event.transaction.hash.concatI32(event.logIndex.toI32())
  )
  entity.from = event.params.from
  entity.to = event.params.to
  entity.tokenId = event.params.tokenId

  entity.blockNumber = event.block.number
  entity.blockTimestamp = event.block.timestamp
  entity.transactionHash = event.transaction.hash

  entity.save()
}
