import { setLengthLeft, setLengthRight, BN } from 'ethereumjs-util'
import { PrecompileInput } from './types'
import { ExecResult } from '../evm'
const assert = require('assert')

export default function (opts: PrecompileInput): ExecResult {
  assert(opts.data)

  const data = setLengthRight(opts.data, 36)

  const sig = data.slice(0, 4).toString('hex')
  assert(sig == 'dcf0aaed')

  const key = data.slice(4, 36).toString('hex')

  // GoldToken
  if (key == 'd7e89ade8430819f08bf97a087285824af3351ee12d72a2d132b0c6c0687bfaf') {
    return {
      gasUsed: new BN(0),
      returnValue: setLengthLeft(
        Buffer.from('471EcE3750Da237f93B8E339c536989b8978a438', 'hex'),
        32
      ),
    }
  }
  // SortedOracles
  if (key == 'ab7ca110ac6f740fa4bdcd667652ab6f883b80daaedaf0cb53396dc5d5be6f2c') {
    return {
      gasUsed: new BN(0),
      returnValue: setLengthLeft(
        Buffer.from('efB84935239dAcdecF7c5bA76d8dE40b077B7b33', 'hex'),
        32
      ),
    }
  }
  // Freezer
  if (key == '24e33447c847c15e68fca3f15a635d2d4d83cb99d7befc9068c4a148521fccf4') {
    return {
      gasUsed: new BN(0),
      returnValue: setLengthLeft(
        Buffer.from('47a472F45057A9d79d62C6427367016409f4fF5A', 'hex'),
        32
      ),
    }
  }

  // eslint-disable-next-line no-console
  console.warn(`Unknown key ${key} requested from registry`)
  return {
    gasUsed: new BN(0),
    returnValue: setLengthLeft(Buffer.from('00', 'hex'), 32),
  }
}
