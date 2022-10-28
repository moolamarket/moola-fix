# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
(modification: no type change headlines) and this project adheres to
[Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## 4.2.2 - 2022-04-29

- Solved memory leak "DPT discovers nodes when open_slots = 0", PR [#1816](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1816)
- Fixed per-message debug logging, PR [#1776](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1776)
- ETH-LES class refactor, PR [#1600](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1600)

## 4.2.1 - 2022-02-01

- Dependencies: deduplicated RLP import, PR [#1549](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1549)
- Fixed duplicated debug messages (`DEBUG` logger, see `README`), PR [#1643](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1643)

## 4.2.0 - 2021-09-24

### EIP-706 Snappy Compression (RLPx v5)

This release adds support for RLPx v5 allowing for the compression of RLPx messages with the Snappy compression algorithm as defined in [EIP-706](https://eips.ethereum.org/EIPS/eip-706). If the connecting peer doesn't support v5, the connection falls back to v4 and does the communication without compressing the payload.

See: PRs [#1399](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1399), [#1442](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1442) and [#1484](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1484)

### Improved Per-Message Debugging

Per-message debugging with the `debug` package has been substantially expanded and allow for a much more targeted debugging experience.

There are new debug loggers added to:

- Debug per specific `ETH` or `LES` message (e.g. `devp2p:eth:GET_BLOCK_HEADERS`)
- Debug per disconnect reason (e.g. `devp2p:rlpx:peer:DISCONNECT:TOO_MANY_PEERS`)
- Debug per peer IP address (e.g. `devp2p:3.209.45.79`)
- Debug per first connected peer (`DEBUG=devp2p:FIRST_PEER`)

See: PR [#1449](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1449)

## 4.1.0 - 2021-07-15

### Finalized London HF Support

This release integrates a `Common` library version which provides the `london` HF blocks for all networks including `mainnet` and is therefore the first release with finalized London HF support. For the `devp2p` library this particularly means that the fork hashes for the `london` HF will be correct when using eth/64 or higher.

### Support for eth/66 and les/4

PR [#1331](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1331) added support for eth/66 and [#1324](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1324) for les/4. Be sure to check out the updated peer communication [examples](./examples).

### Included Source Files

Source files from the `src` folder are now included in the distribution build, see PR [#1301](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1301). This allows for a better debugging experience in debug tools like Chrome DevTools by having working source map references to the original sources available for inspection.

### Bug Fixes

- Fixed zero Buffer forkhash bug in case no future fork known, PR #1148 commit [`afd00a8`](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1148/commits/afd00a8bfee1b524352a0f6c79f3bcfe43debe4c)

## 4.0.0 - 2021-04-22

**Attention!** This new version is part of a series of EthereumJS releases all moving to a new scoped package name format. In this case the library is renamed as follows:

- `ethereumjs-devp2p` -> `@ethereumjs/devp2p`

Please update your library references accordingly or install with:

```shell
npm i @ethereumjs/devp2p
```

This is the first-production ready release of this library. During our work on the [EthereumJS Client](https://github.com/ethereumjs/ethereumjs-monorepo/tree/master/packages/client) we were finally able to battle-test this library in a real-world environment (so: towards `mainnet`, the main official testnets like `goerli` or `rinkeby` as well as ephemeral testnets like `yolov3`). We fixed a myriad of partly critical bugs along the way (which are extremely hard to reproduce just in a test environment) and can now fully recommend to use this library for `ETH` protocol integrations up to version `ETH/65` in a production setup. Note that the `LES` support in the library is still outdated (but working), an update is planned (let us know if you have demand).

### ETH/64 and ETH/65 Support

The `ETH` protocol support has been updated to now also support versions `64` and `65`. Biggest protocol update here is `ETH/64` introduced with PR [#82](https://github.com/ethereumjs/ethereumjs-devp2p/pull/82) which adds support for selecting peers by fork ID (see associated [EIP-2124](https://eips.ethereum.org/EIPS/eip-2124)). This allows for a much more differentiated chain selection and avoids connecting to peers which are on a different chain but having a shared chain history with the same blocks and the same block hashes.

`ETH/65` implemented in PR [#1159](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1159) adds three new message types `NewPooledTransactionHashes (0x08)`, `GetPooledTransactions (0x09)` and `PooledTransactions (0x0a)` for a more efficient exchange on txs from the tx pool ([EIP-2464](https://eips.ethereum.org/EIPS/eip-2464)).

### DNS Discovery Support

Node discovery via DNS has been added to quickly acquire testnet (or mainnet) peers from the DNS ENR tree per [EIP-1459](https://eips.ethereum.org/EIPS/eip-1459), see PRs [#1070](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1070), [#1097](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1097) and [#1149](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1149). This allows for easier peer discovery especially on the testnets. Peer search is randomized as being recommended in the EIP and the implementation avoids to download the entire DNS tree at once. 

DNS discovery can be activated in the `DPT` module with the `shouldGetDnsPeers` option, in addition there is a new `shouldFindNeighbours` option allowing to deactivate the classical v4 discovery process. Both discovery methods can be used in conjunction though. DNS Peer discovery can be customized/configured with additional constructor options `dnsRefreshQuantity`, `dnsNetworks` and `dnsAddress`. See [API section](https://github.com/ethereumjs/ethereumjs-monorepo/tree/master/packages/devp2p#api) in the README for a description.

### Other Features / Changes

- Updated `goerli` bootnodes, PR [#1031](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1031)
- `maxPeers`, `dpt`, and `listenPort` are now optional in `RLPxOptions`, PR [#1019](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1019)
- New `DPTOptions` interface, `DPT` type improvements, PR [#1029](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1029)
- Improved `RLPx` disconnect reason debug output, PR [#1031](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1031)
- `LES`: unifiy `ETH` and `LES` `sendMessage()` signature by somewhat change payload semantics and pass in `reqId` along, PR [#1087](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1087)
- `RLPx`: limit connection refill debug logging to a restarted interval log message to not bloat logging too much, PR [#1087](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1087)

### Connection Reliability / Bug Fixes

- Subdivided interval calls to refill `RLPx` peer connections to improve networking distribution and connection reliability, PR [#1036](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1036)
- Fixed an error in `DPT` not properly banning old peers and replacing with a new peer on `KBucket` ping, PR [#1036](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1036)
- Connection reliability: distribute network traffic on `DPT` additions of new neighbour peers, PR [#1036](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1036)
- Fixed a critical peer data processing bug, PR [#1064](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1064)
- Added socket destroyed checks on peer message sending to safeguard against stream-was-destroyed error, PR [#1075](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1075)
- `DPT`: fixed undefined array access in ETH._getStatusString() on malformed ETH/64 status msgs, PR [#1029](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1029)

### Maintenance / Testing / CI

- Added dedicated browser build published to `dist.browser` to `package.json`, PR [#1184](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1184)
- Updated `rlp-encoding` dependency to the EthereumJS `rlp` library, PR [#94](https://github.com/ethereumjs/ethereumjs-devp2p/pull/94)
- `RLPx` type improvements, PR [#1036](https://github.com/ethereumjs/ethereumjs-monorepo/pull/1036)
- Switched to `Codecov`, PR [#92](https://github.com/ethereumjs/ethereumjs-devp2p/pull/92)
- Upgraded dev deps (config 2.0, monorepo betas, typedoc), PR [#93](https://github.com/ethereumjs/ethereumjs-devp2p/pull/93)

## [3.0.3] - 2020-09-29

- Moved `TypeScript` type packages for `lru-cache` and `bl` from `devDependencies` to
  `dependencies`, PR [#90](https://github.com/ethereumjs/ethereumjs-devp2p/pull/90)

[3.0.3]: https://github.com/ethereumjs/ethereumjs-devp2p/compare/v3.0.2...v3.0.3

## [3.0.2] - 2020-09-28

- Fixed `TypeScript` import issue causing problems when integrating the library in a
  `TypeScript` project, PR [#88](https://github.com/ethereumjs/ethereumjs-devp2p/pull/88)
- Updated `k-bucket` library to `v5`, added types from new `@types/k-bucket` package from
  @tomonari-t, PR [#88](https://github.com/ethereumjs/ethereumjs-devp2p/pull/88)

[3.0.2]: https://github.com/ethereumjs/ethereumjs-devp2p/compare/v3.0.1...v3.0.2

## [3.0.1] - 2020-06-10

This release focuses on improving the [debugging](https://github.com/ethereumjs/ethereumjs-devp2p#debugging)
capabilities of the library. PR [#72](https://github.com/ethereumjs/ethereumjs-devp2p/pull/72)
reduces the **verbosity** of the log output to cut on noise on everyday debugging. There is a new `verbose`
logger to retain the more verbose output (e.g. with full message bodies) which can be used like this:

```shell
DEBUG=devp2p:*,verbose node -r ts-node/register ./examples/peer-communication.ts
```

**Other Logging Improvements**

Relevant PRs [#75](https://github.com/ethereumjs/ethereumjs-devp2p/pull/75) and
[#73](https://github.com/ethereumjs/ethereumjs-devp2p/pull/73):

- Added number of peers to `refillConnections()` debug message
- Replaced try/catch logic for EIP-8 auth check to avoid side-effects and get rid of misleading _wrong-ecies-header_ debug output
- Moved debug output in `BanList.add()` after the set operation to get the correct size output
- Added debug message for `DISCONNECT` reason from peer (this was always some constant re-debug reason, and at the end it's mostly `TOO_MANY_PEERS`)
- Internalize detached logger output from the `devp2p:util` logger

**Other Changes**

- Refactored `Peer` class for better code readability, PR [#77](https://github.com/ethereumjs/ethereumjs-devp2p/pull/77)

There has also been a new [high-level diagram](https://github.com/ethereumjs/ethereumjs-devp2p#api) added to the `README` which can be used to get an overview on the structure, available loggers and the event flow of the library (PR [#76](https://github.com/ethereumjs/ethereumjs-devp2p/pull/76)).

[3.0.1]: https://github.com/ethereumjs/ethereumjs-devp2p/compare/v3.0.0...v3.0.1

## [3.0.0] - 2020-05-25

First `TypeScript` release of the library, see PR [#56](https://github.com/ethereumjs/ethereumjs-devp2p/pull/56) for all the changes and associated discussion.

All source parts of the library have been ported to `TypeScript` and working with the library should now therefore be much more reliable due to the additional type safety features provided by the `TypeScript` language. The API of the library remains unchanged in a `JavaScript` context.

**Noteworthy Changes from PR [#56](https://github.com/ethereumjs/ethereumjs-devp2p/pull/56):**

- Type additions for all method signatures and class members of all protocol components (`dpt`, `eth`, `les`, `rlpx`)
- Addition of various structuring interfaces (like [PeerInfo](https://github.com/ethereumjs/ethereumjs-devp2p/blob/master/src/dpt/message.ts#L10) for `DPT` message input) and `enum` constructs (like [MESSAGE_CODES](https://github.com/ethereumjs/ethereumjs-devp2p/blob/master/src/eth/index.ts#L186) from the `ETH` protocol)
- Port of the [examples](https://github.com/ethereumjs/ethereumjs-devp2p/tree/master/examples) to `TypeScript`
- Port of all the [test cases](https://github.com/ethereumjs/ethereumjs-devp2p/tree/master/test) to `TypeScript`
- Integration of the library into the common [ethereumjs-config](https://github.com/ethereumjs/ethereumjs-config) EthereumJS configuration setup (`standard` -> `TSLint` linting, docs with `TypeDoc`, `TypeScript` compilation, `Prettier` formatting rules)
- Lots of code cleanups and code part modernizations

Thanks @dryajov for all the great work on this! ❤

**Other Updates:**

- Added Node 12,13 support, upgrade from Travis to GitHub actions, PR [#57](https://github.com/ethereumjs/ethereumjs-devp2p/pull/57)
- Updated `ethereumjs-common` dependency to `v1.5.1` for a bootnode update, PR [#67](https://github.com/ethereumjs/ethereumjs-devp2p/pull/67)
- Removed Node 6, 8 support, updated `secp256k1` dependency to from `v3.1.0` to `v4.0.1`, PR [#68](https://github.com/ethereumjs/ethereumjs-devp2p/pull/68)
- Updated `keccak` dependency to `v3.0.0`, PR [#64](https://github.com/ethereumjs/ethereumjs-devp2p/pull/64)
- Some dependency cleanup, PRs [#62](https://github.com/ethereumjs/ethereumjs-devp2p/pull/62), [#65](https://github.com/ethereumjs/ethereumjs-devp2p/pull/65), [#58](https://github.com/ethereumjs/ethereumjs-devp2p/pull/58)

[3.0.0]: https://github.com/ethereumjs/ethereumjs-devp2p/compare/v2.5.1...v3.0.0

## [2.5.1] - 2018-12-12

- Fix connection error by ignoring `RLPX` peers with missing tcp port, PR [#45](https://github.com/ethereumjs/ethereumjs-devp2p/pull/45)

[2.5.1]: https://github.com/ethereumjs/ethereumjs-devp2p/compare/v2.5.0...v2.5.1

## [2.5.0] - 2018-03-22

- Light client protocol (`LES/2`) implementation, PR [#21](https://github.com/ethereumjs/ethereumjs-devp2p/pull/21)
- `LES/2` usage example, see: `examples/peer-communication-les.js`
- Better test coverage for upper-layer protocols (`ETH`, `LES/2`), PR [#34](https://github.com/ethereumjs/ethereumjs-devp2p/pull/34)

[2.5.0]: https://github.com/ethereumjs/ethereumjs-devp2p/compare/v2.4.0...v2.5.0

## [2.4.0] - 2018-02-28

- First release providing a reliable `ETH` connection
- Fix Parity `DPT` ping echo hash bug preventing the library to connect
  to Parity clients, PR [#32](https://github.com/ethereumjs/ethereumjs-devp2p/pull/32)
- Fixed a bug not setting weHello in peer after sent `HELLO` msg

[2.4.0]: https://github.com/ethereumjs/ethereumjs-devp2p/compare/v2.3.0...v2.4.0

## [2.3.0] - 2018-02-27

- Fix critical `RLPX` bug leading to not processing incoming `EIP-8` `Auth` or `Ack` messages, PR [#26](https://github.com/ethereumjs/ethereumjs-devp2p/pull/26)
- Fix bug not forwarding `k-bucket` remove event through `DPT` (so `peer:removed` from
  `DPT` was not working), PR [#27](https://github.com/ethereumjs/ethereumjs-devp2p/pull/27)
- Fix updating `ingressMac` with wrong `Auth` msg leading to diverging `Mac` hashes, PR [#29](https://github.com/ethereumjs/ethereumjs-devp2p/pull/29)
- Fix bug not let first `ETH` `status` message emit a `message` event, PR [#30](https://github.com/ethereumjs/ethereumjs-devp2p/pull/30)
- Large rework of the test setup, additional `DPT`, `RLPX` and `ETH` simulator tests,
  improving test coverage from 48% to 84%, PR [#25](https://github.com/ethereumjs/ethereumjs-devp2p/pull/25)

[2.3.0]: https://github.com/ethereumjs/ethereumjs-devp2p/compare/v2.2.0...v2.3.0

## [2.2.0] - 2017-12-07

- `EIP-8` compatibility
- Improved debug messages
- Fixes a bug on DPT ping timeout being triggered even if pong message is received
- Only send connect event after both HELLO msgs are exchanged (fixes unreliable upper-protocol communication start)
- Connection reliability improvements for `peer-communication` example
- API documentation

[2.2.0]: https://github.com/ethereumjs/ethereumjs-devp2p/compare/v2.1.3...v2.2.0

## [2.1.3] - 2017-11-09

- Dependency updates
- Improved README documentation

[2.1.3]: https://github.com/ethereumjs/ethereumjs-devp2p/compare/v2.1.2...v2.1.3

## Older releases:

- [2.1.2](https://github.com/ethereumjs/ethereumjs-devp2p/compare/v2.1.1...v2.1.2) - 2017-05-16
- [2.1.1](https://github.com/ethereumjs/ethereumjs-devp2p/compare/v2.1.0...v2.1.1) - 2017-04-27
- [2.1.0](https://github.com/ethereumjs/ethereumjs-devp2p/compare/v2.0.0...v2.1.0) - 2016-12-11
- [2.0.0](https://github.com/ethereumjs/ethereumjs-devp2p/compare/v1.0.0...v2.0.0) - 2016-11-14
- 1.0.0 - 2016-10-18
