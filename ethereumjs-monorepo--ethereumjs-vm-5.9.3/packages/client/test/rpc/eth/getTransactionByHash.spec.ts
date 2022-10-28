import tape from 'tape'
import { Transaction, FeeMarketEIP1559Transaction } from '@ethereumjs/tx'
import { bufferToHex } from 'ethereumjs-util'
import {
  params,
  baseRequest,
  setupChain,
  runBlockWithTxs,
  gethGenesisStartLondon,
  dummy,
} from '../helpers'
import pow from './../../testdata/geth-genesis/pow.json'

const method = 'eth_getTransactionByHash'

tape(`${method}: call with legacy tx`, async (t) => {
  const { chain, common, execution, server } = await setupChain(pow, 'pow', { txLookupLimit: 1 })

  // construct tx
  const tx = Transaction.fromTxData(
    { gasLimit: 2000000, gasPrice: 100, to: '0x0000000000000000000000000000000000000000' },
    { common }
  ).sign(dummy.privKey)

  await runBlockWithTxs(chain, execution, [tx])

  // get the tx
  let req = params(method, [bufferToHex(tx.hash())])
  let expectRes = (res: any) => {
    const msg = 'should return the correct tx'
    t.equal(res.body.result.hash, bufferToHex(tx.hash()), msg)
  }
  await baseRequest(t, server, req, 200, expectRes, false)

  // run a block to ensure tx hash index is cleaned up when txLookupLimit=1
  await runBlockWithTxs(chain, execution, [])
  req = params(method, [bufferToHex(tx.hash())])
  expectRes = (res: any) => {
    const msg = 'should return null when past txLookupLimit'
    t.equal(res.body.result, null, msg)
  }
  await baseRequest(t, server, req, 200, expectRes, true) // pass endOnFinish=true for last test
})

tape(`${method}: call with 1559 tx`, async (t) => {
  const { chain, common, execution, server } = await setupChain(
    gethGenesisStartLondon(pow),
    'powLondon',
    { txLookupLimit: 0 }
  )

  // construct tx
  const tx = FeeMarketEIP1559Transaction.fromTxData(
    {
      gasLimit: 2000000,
      maxFeePerGas: 975000000,
      maxPriorityFeePerGas: 10,
      to: '0x0000000000000000000000000000000000000000',
    },
    { common }
  ).sign(dummy.privKey)

  await runBlockWithTxs(chain, execution, [tx])

  // get the tx
  let req = params(method, [bufferToHex(tx.hash())])
  let expectRes = (res: any) => {
    const msg = 'should return the correct tx type'
    t.equal(res.body.result.type, '0x2', msg)
  }
  await baseRequest(t, server, req, 200, expectRes, false)

  // run some blocks to ensure tx hash index is not cleaned up when txLookupLimit=0
  await runBlockWithTxs(chain, execution, [])
  await runBlockWithTxs(chain, execution, [])
  await runBlockWithTxs(chain, execution, [])
  req = params(method, [bufferToHex(tx.hash())])
  expectRes = (res: any) => {
    const msg = 'should return the correct tx when txLookupLimit=0'
    t.equal(res.body.result.hash, bufferToHex(tx.hash()), msg)
  }
  await baseRequest(t, server, req, 200, expectRes, true) // pass endOnFinish=true for last test
})

tape(`${method}: call with unknown tx hash`, async (t) => {
  const { server } = await setupChain(pow, 'pow')

  // get a random tx hash
  const req = params(method, ['0x89ea5b54111befb936851660a72b686a21bc2fc4889a9a308196ff99d08925a0'])
  const expectRes = (res: any) => {
    const msg = 'should return null'
    t.equal(res.body.result, null, msg)
  }
  await baseRequest(t, server, req, 200, expectRes)
})
