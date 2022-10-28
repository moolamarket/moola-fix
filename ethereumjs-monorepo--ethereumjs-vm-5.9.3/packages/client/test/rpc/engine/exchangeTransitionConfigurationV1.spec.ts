import tape from 'tape'
import { INVALID_PARAMS } from '../../../lib/rpc/error-code'
import { params, baseRequest, setupChain } from '../helpers'
import { checkError } from '../util'
import genesisJSON from '../../testdata/geth-genesis/post-merge.json'

const method = 'engine_exchangeTransitionConfigurationV1'

const validConfig = {
  terminalTotalDifficulty: '0x0',
  terminalBlockHash: '0x1d93f244823f80efbd9292a0d0d72a2b03df8cd5a9688c6c3779d26a7cc5009c',
  terminalBlockNumber: '0x0',
}

const invalidConfig = {
  terminalTotalDifficulty: '0x100',
  terminalBlockHash: '0x1d93f244823f80efbd9292a0d0d72a2b03df8cd5a9688c6c3779d26a7cc5009c',
  terminalBlockNumber: '0x0',
}

tape(`${method}: call with valid config`, async (t) => {
  const { server } = await setupChain(genesisJSON, 'post-merge', { engine: true })

  const req = params(method, [validConfig])
  const expectRes = (res: any) => {
    t.deepEqual(res.body.result, validConfig)
  }
  await baseRequest(t, server, req, 200, expectRes)
})

tape(`${method}: call with invalid config`, async (t) => {
  const { server } = await setupChain(genesisJSON, 'post-merge', { engine: true })

  const req = params(method, [invalidConfig])
  const expectRes = checkError(t, INVALID_PARAMS, 'terminalTotalDifficulty set to 0, received 256')
  await baseRequest(t, server, req, 200, expectRes)
})
