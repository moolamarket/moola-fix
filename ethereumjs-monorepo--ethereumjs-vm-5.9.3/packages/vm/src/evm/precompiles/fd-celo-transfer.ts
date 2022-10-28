import { setLengthRight, BN, Address } from 'ethereumjs-util'
import { PrecompileInput } from './types'
import { ExecResult } from '../evm'
const assert = require('assert')

export default async function (opts: PrecompileInput): Promise<ExecResult> {
  assert(opts.data)

  const data = setLengthRight(opts.data, 96)

  const fromAddress = new Address(data.slice(12, 32))
  const toAddress = new Address(data.slice(44, 64))
  const amount = new BN(data.slice(64, 96).toString('hex'), 16)

  const fromAccount = await opts._VM.stateManager.getAccount(fromAddress)
  fromAccount.balance.isub(amount)
  await opts._VM.stateManager.putAccount(fromAddress, fromAccount)
  const toAccount = await opts._VM.stateManager.getAccount(toAddress)
  toAccount.balance.iadd(amount)
  await opts._VM.stateManager.putAccount(toAddress, toAccount)

  return {
    gasUsed: new BN(0),
    returnValue: Buffer.alloc(0),
  }
}
