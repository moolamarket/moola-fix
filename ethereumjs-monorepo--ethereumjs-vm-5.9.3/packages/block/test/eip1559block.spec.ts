import tape from 'tape'
import Common, { Chain, Hardfork } from '@ethereumjs/common'
import { BlockHeader } from '../src/header'
import { BN } from 'ethereumjs-util'
import { Mockchain } from './mockchain'
import { Block } from '../src/block'
import { FeeMarketEIP1559Transaction } from '@ethereumjs/tx'

// Test data from Besu (retrieved via Discord)
// Older version at https://github.com/abdelhamidbakhta/besu/blob/bf54b6c0b40d3015fc85ff9b078fbc26592d80c0/ethereum/core/src/test/resources/org/hyperledger/besu/ethereum/core/fees/basefee-test.json
const eip1559BaseFee = require('./testdata/eip1559baseFee.json')

const common = new Common({
  eips: [1559],
  chain: Chain.Mainnet,
  hardfork: Hardfork.London,
})

const blockchain1 = new Mockchain()
const blockchain2 = new Mockchain()

const genesis = Block.fromBlockData({})

// Small hack to hack in the activation block number
// (Otherwise there would be need for a custom chain only for testing purposes)
common.hardforkBlockBN = function (hardfork: string | undefined) {
  if (hardfork === 'london') {
    return new BN(1)
  } else if (hardfork === 'dao') {
    // Avoid DAO HF side-effects
    return new BN(99)
  }
  return new BN(0)
}

tape('EIP1559 tests', function (t) {
  t.test('Initialize test suite', async function (st) {
    await blockchain1.putBlock(genesis)
    await blockchain2.putBlock(genesis)
    st.end()
  })

  t.test('Header -> Initialization', function (st) {
    const common = new Common({ chain: Chain.Mainnet, hardfork: Hardfork.Istanbul })
    st.throws(() => {
      BlockHeader.fromHeaderData(
        {
          number: new BN(1),
          parentHash: genesis.hash(),
          timestamp: new BN(1),
          gasLimit: genesis.header.gasLimit.muln(2), // Special case on EIP-1559 transition block
          baseFeePerGas: new BN(5),
        },
        {
          common,
        }
      ),
        'should throw when setting baseFeePerGas with EIP1559 not being activated'
    })
    st.end()
  })

  t.test('Header -> validate()', async function (st) {
    const header = BlockHeader.fromHeaderData(
      {
        number: new BN(1),
        parentHash: genesis.hash(),
        gasLimit: genesis.header.gasLimit.muln(2), // Special case on EIP-1559 transition block
        timestamp: new BN(1),
        baseFeePerGas: 100,
      },
      {
        calcDifficultyFromHeader: genesis.header,
        common,
        freeze: false,
      }
    )

    try {
      await header.validate(blockchain1)
      st.fail('should throw when baseFeePerGas is not set to initial base fee')
    } catch (e: any) {
      const expectedError = 'Initial EIP1559 block does not have initial base fee'
      st.ok(
        e.message.includes(expectedError),
        'should throw if base fee is not set to initial value'
      )
    }

    try {
      ;(header as any).baseFeePerGas = undefined
      await header.validate(blockchain1)
    } catch (e: any) {
      const expectedError = 'EIP1559 block has no base fee field'
      st.ok(
        e.message.includes(expectedError),
        'should throw with no base fee field when EIP1559 is activated'
      )
    }

    ;(header as any).baseFeePerGas = new BN(7) // reset for next test
    const block = Block.fromBlockData({ header }, { common })
    try {
      const blockchain = Object.create(blockchain1)
      await blockchain.putBlock(block)
      const header = BlockHeader.fromHeaderData(
        {
          number: new BN(2),
          parentHash: block.hash(),
          gasLimit: block.header.gasLimit,
          timestamp: new BN(10),
          baseFeePerGas: new BN(1000),
        },
        {
          calcDifficultyFromHeader: block.header,
          common,
        }
      )
      await header.validate(blockchain)
    } catch (e: any) {
      const expectedError = 'Invalid block: base fee not correct'
      st.ok(e.message.includes(expectedError), 'should throw when base fee is not correct')
    }

    st.end()
  })

  const block1 = Block.fromBlockData(
    {
      header: {
        number: new BN(1),
        parentHash: genesis.hash(),
        gasLimit: genesis.header.gasLimit.muln(2), // Special case on EIP-1559 transition block
        timestamp: new BN(1),
        baseFeePerGas: new BN(common.param('gasConfig', 'initialBaseFee')),
      },
    },
    {
      calcDifficultyFromHeader: genesis.header,
      common,
    }
  )

  t.test('Header -> validate() -> success case', async function (st) {
    await block1.header.validate(blockchain1)
    await blockchain2.putBlock(block1)
    st.pass('Valid initial EIP1559 header should be valid')

    st.end()
  })

  t.test('Header -> validate()', async function (st) {
    const header = BlockHeader.fromHeaderData(
      {
        baseFeePerGas: new BN(1000),
        number: new BN(1),
        parentHash: genesis.hash(),
        gasLimit: genesis.header.gasLimit.muln(2), // Special case on EIP-1559 transition block
        timestamp: new BN(1),
      },
      {
        calcDifficultyFromHeader: genesis.header,
        common,
      }
    )

    try {
      await header.validate(blockchain1)
      st.fail('should throw')
    } catch (e: any) {
      st.ok(e.message.includes('base fee'), 'should throw on wrong initial base fee')
    }
    st.end()
  })

  t.test('Header -> validate() -> success cases', async function (st) {
    const block = Block.fromBlockData(
      {
        header: {
          number: new BN(2),
          parentHash: block1.hash(),
          timestamp: new BN(2),
          gasLimit: genesis.header.gasLimit.muln(2), // Special case on EIP-1559 transition block
          baseFeePerGas: Buffer.from('342770c0', 'hex'),
        },
      },
      {
        calcDifficultyFromHeader: block1.header,
        common,
      }
    )
    // blockchain2 has block 1 added at this moment (see test above)
    await block.header.validate(blockchain2)
    st.pass('should correctly validate subsequent EIP-1559 blocks')
    st.end()
  })

  t.test('Header -> validate() -> gas usage', async function (st) {
    const header = BlockHeader.fromHeaderData(
      {
        number: new BN(1),
        parentHash: genesis.hash(),
        timestamp: new BN(1),
        gasLimit: genesis.header.gasLimit.muln(2), // Special case on EIP-1559 transition block
        gasUsed: genesis.header.gasLimit
          .muln(common.param('gasConfig', 'elasticityMultiplier'))
          .addn(1),
        baseFeePerGas: new BN(common.param('gasConfig', 'initialBaseFee')),
      },
      {
        calcDifficultyFromHeader: genesis.header,
        common,
      }
    )

    try {
      await header.validate(blockchain1)
      st.fail('should throw')
    } catch (e: any) {
      st.ok(e.message.includes('too much gas used'), 'should throw when elasticity is exceeded')
    }
    st.end()
  })

  t.test('Header -> validate() -> gas usage', async function (st) {
    const header = BlockHeader.fromHeaderData(
      {
        number: new BN(1),
        parentHash: genesis.hash(),
        timestamp: new BN(1),
        gasLimit: genesis.header.gasLimit.muln(2), // Special case on EIP-1559 transition block
        gasUsed: genesis.header.gasLimit.muln(2),
        baseFeePerGas: new BN(common.param('gasConfig', 'initialBaseFee')),
      },
      {
        calcDifficultyFromHeader: genesis.header,
        common,
      }
    )

    await header.validate(blockchain1)
    st.pass('should not throw when elasticity is exactly matched')
    st.end()
  })

  t.test('Header -> validate() -> gasLimit -> success cases', async function (st) {
    let parentGasLimit = genesis.header.gasLimit.muln(2)
    let header = BlockHeader.fromHeaderData(
      {
        number: new BN(1),
        parentHash: genesis.hash(),
        timestamp: new BN(1),
        gasLimit: parentGasLimit.add(parentGasLimit.divn(1024)).subn(1),
        baseFeePerGas: new BN(common.param('gasConfig', 'initialBaseFee')),
      },
      {
        calcDifficultyFromHeader: genesis.header,
        common,
      }
    )
    await header.validate(blockchain1)
    st.pass('should not throw if gas limit is between bounds (HF transition block)')

    header = BlockHeader.fromHeaderData(
      {
        number: new BN(1),
        parentHash: genesis.hash(),
        timestamp: new BN(1),
        gasLimit: parentGasLimit.sub(parentGasLimit.divn(1024)).addn(1),
        baseFeePerGas: new BN(common.param('gasConfig', 'initialBaseFee')),
      },
      {
        calcDifficultyFromHeader: genesis.header,
        common,
      }
    )
    await header.validate(blockchain1)
    st.pass('should not throw if gas limit is between bounds (HF transition block)')

    parentGasLimit = block1.header.gasLimit
    header = BlockHeader.fromHeaderData(
      {
        number: new BN(2),
        parentHash: block1.hash(),
        timestamp: new BN(2),
        gasLimit: parentGasLimit.add(parentGasLimit.divn(1024)).subn(1),
        baseFeePerGas: Buffer.from('342770c0', 'hex'),
      },
      {
        calcDifficultyFromHeader: block1.header,
        common,
      }
    )
    await header.validate(blockchain2)
    st.pass('should not throw if gas limit is between bounds (post-HF transition block)')

    header = BlockHeader.fromHeaderData(
      {
        number: new BN(2),
        parentHash: block1.hash(),
        timestamp: new BN(2),
        gasLimit: parentGasLimit.sub(parentGasLimit.divn(1024)).addn(1),
        baseFeePerGas: Buffer.from('342770c0', 'hex'),
      },
      {
        calcDifficultyFromHeader: block1.header,
        common,
      }
    )
    await header.validate(blockchain2)
    st.pass('should not throw if gas limit is between bounds (post-HF transition block)')
    st.end()
  })

  t.test('Header -> validate() -> gasLimit -> error cases', async function (st) {
    let parentGasLimit = genesis.header.gasLimit.muln(2)
    let header = BlockHeader.fromHeaderData(
      {
        number: new BN(1),
        parentHash: genesis.hash(),
        timestamp: new BN(1),
        gasLimit: parentGasLimit.add(parentGasLimit.divn(1024)),
        baseFeePerGas: new BN(common.param('gasConfig', 'initialBaseFee')),
      },
      {
        calcDifficultyFromHeader: genesis.header,
        common,
      }
    )
    try {
      await header.validate(blockchain1)
      st.fail('should throw')
    } catch (e: any) {
      st.ok(
        e.message.includes('invalid gas limit'),
        'should throw if gas limit is increased too much (HF transition block)'
      )
    }

    parentGasLimit = block1.header.gasLimit
    header = BlockHeader.fromHeaderData(
      {
        number: new BN(2),
        parentHash: block1.hash(),
        timestamp: new BN(2),
        gasLimit: parentGasLimit.add(parentGasLimit.divn(1024)),
        baseFeePerGas: Buffer.from('342770c0', 'hex'),
      },
      {
        calcDifficultyFromHeader: block1.header,
        common,
      }
    )
    try {
      await header.validate(blockchain2)
      st.fail('should throw')
    } catch (e: any) {
      st.ok(
        e.message.includes('invalid gas limit'),
        'should throw if gas limit is increased too much (post-HF transition block)'
      )
    }
    st.end()
  })

  t.test('Header -> validate() -> gasLimit -> error cases', async function (st) {
    let parentGasLimit = genesis.header.gasLimit.muln(2)
    let header = BlockHeader.fromHeaderData(
      {
        number: new BN(1),
        parentHash: genesis.hash(),
        timestamp: new BN(1),
        gasLimit: parentGasLimit.sub(parentGasLimit.divn(1024)),
        baseFeePerGas: new BN(common.param('gasConfig', 'initialBaseFee')),
      },
      {
        calcDifficultyFromHeader: genesis.header,
        common,
      }
    )
    try {
      await header.validate(blockchain1)
      st.fail('should throw')
    } catch (e: any) {
      st.ok(
        e.message.includes('invalid gas limit'),
        'should throw if gas limit is decreased too much (HF transition block)'
      )
    }

    parentGasLimit = block1.header.gasLimit
    header = BlockHeader.fromHeaderData(
      {
        number: new BN(2),
        parentHash: block1.hash(),
        timestamp: new BN(2),
        gasLimit: parentGasLimit.sub(parentGasLimit.divn(1024)),
        baseFeePerGas: Buffer.from('342770c0', 'hex'),
      },
      {
        calcDifficultyFromHeader: block1.header,
        common,
      }
    )
    try {
      await header.validate(blockchain2)
      st.fail('should throw')
    } catch (e: any) {
      st.ok(
        e.message.includes('invalid gas limit'),
        'should throw if gas limit is decreased too much (post-HF transition block)'
      )
    }
    st.end()
  })

  t.test('Header -> validate() -> tx', async (st) => {
    const transaction = FeeMarketEIP1559Transaction.fromTxData(
      {
        maxFeePerGas: new BN(0),
        maxPriorityFeePerGas: new BN(0),
      },
      { common }
    ).sign(Buffer.from('46'.repeat(32), 'hex'))
    const block = Block.fromBlockData(
      {
        header: {
          number: new BN(1),
          parentHash: genesis.hash(),
          gasLimit: genesis.header.gasLimit.muln(2), // Special case on EIP-1559 transition block
          timestamp: new BN(1),
          baseFeePerGas: new BN(common.param('gasConfig', 'initialBaseFee')),
        },
        transactions: [
          {
            maxFeePerGas: new BN(0),
            maxPriorityFeePerGas: new BN(0),
            type: 2,
            v: transaction.v,
            r: transaction.r,
            s: transaction.s,
            gasLimit: 53000,
          },
        ],
      },
      {
        common,
        calcDifficultyFromHeader: genesis.header,
      }
    )
    try {
      await block.validate(blockchain1)
      st.fail('should throw')
    } catch (e: any) {
      st.ok(
        e.message.includes('unable to pay base fee'),
        'should throw if transaction is unable to pay base fee'
      )
    }

    st.end()
  })

  t.test('Header -> calcNextBaseFee()', function (st) {
    for (let index = 0; index < eip1559BaseFee.length; index++) {
      const item = eip1559BaseFee[index]
      const result = BlockHeader.fromHeaderData(
        {
          baseFeePerGas: new BN(item.parentBaseFee),
          gasUsed: new BN(item.parentGasUsed),
          gasLimit: new BN(item.parentTargetGasUsed).muln(2),
        },
        { common }
      ).calcNextBaseFee()
      const expected = new BN(item.expectedBaseFee)
      st.ok(expected.eq(result), 'base fee correct')
    }
    st.end()
  })

  t.test('Header -> toJSON()', function (st) {
    const header = BlockHeader.fromHeaderData(
      {
        number: new BN(1),
        parentHash: genesis.hash(),
        timestamp: new BN(1),
        gasLimit: genesis.header.gasLimit,
        baseFeePerGas: new BN(5),
      },
      {
        common,
      }
    )
    st.equal(header.toJSON().baseFee, '0x5')
    st.end()
  })
})
