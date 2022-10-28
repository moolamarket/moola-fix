/**
 * Libp2p Bundle
 * @memberof module:net/peer
 */

import { NOISE } from '@chainsafe/libp2p-noise'
import LibP2p from 'libp2p'
import { Multiaddr } from 'multiaddr'
import PeerId from 'peer-id'
import Bootstrap from 'libp2p-bootstrap'
const TCP = require('libp2p-tcp')
const Websockets = require('libp2p-websockets')
const filters = require('libp2p-websockets/src/filters')
const KadDht = require('libp2p-kad-dht')
const MPLEX = require('libp2p-mplex')

export interface Libp2pNodeOptions {
  /* Peer id */
  peerId: PeerId

  /* Addresses */
  addresses?: {
    listen?: string[]
    announce?: string[]
    announceFilter?: (ma: Multiaddr[]) => Multiaddr[]
  }

  /* Bootnodes */
  bootnodes?: Multiaddr[]
}

export class Libp2pNode extends LibP2p {
  constructor(options: Libp2pNodeOptions) {
    const wsTransportKey = Websockets.prototype[Symbol.toStringTag]
    options.bootnodes = options.bootnodes ?? []
    super({
      peerId: options.peerId,
      addresses: options.addresses,
      modules: {
        transport: [TCP, Websockets],
        streamMuxer: [MPLEX],
        connEncryption: [NOISE],
        [<any>'peerDiscovery']: [Bootstrap],
        [<any>'dht']: KadDht,
      },
      config: {
        transport: {
          [wsTransportKey]: {
            filter: filters.all,
          },
        },
        peerDiscovery: {
          autoDial: false,
          [Bootstrap.tag]: {
            interval: 2000,
            enabled: options.bootnodes.length > 0,
            list: options.bootnodes,
          },
        },
        dht: {
          kBucketSize: 20,
        },
      },
    })
  }
}
