import tape from 'tape'
import { BN } from 'ethereumjs-util'
import { INVALID_PARAMS } from '../../../lib/rpc/error-code'
import { startRPC, createManager, createClient, params, baseRequest } from '../helpers'
import { checkError } from '../util'

function createChain() {
  const block = {
    uncleHeaders: ['0x1', '0x2', '0x3'],
    transactions: [],
    header: {
      hash: () => Buffer.from([1]),
      number: new BN('5'),
    },
  }
  return {
    blocks: { latest: block },
    headers: { latest: block.header },
    getBlock: () => block,
    getLatestBlock: () => block,
    getLatestHeader: () => block.header,
  }
}

const method = 'eth_getUncleCountByBlockNumber'

tape(`${method}: call with valid arguments`, async (t) => {
  const mockUncleCount = 3

  const manager = createManager(createClient({ chain: createChain() }))
  const server = startRPC(manager.getMethods())

  const req = params(method, ['0x1'])
  const expectRes = (res: any) => {
    const msg = 'should return the correct number'
    t.equal(res.body.result, mockUncleCount, msg)
  }
  await baseRequest(t, server, req, 200, expectRes)
})

tape(`${method}: call with invalid block number`, async (t) => {
  const manager = createManager(createClient({ chain: createChain() }))
  const server = startRPC(manager.getMethods())

  const req = params(method, ['0x5a'])

  const expectRes = checkError(t, INVALID_PARAMS, 'specified block greater than current height')
  await baseRequest(t, server, req, 200, expectRes)
})
