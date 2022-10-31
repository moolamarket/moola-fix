# Moola Fix

You will need nodejs v16.

To install do:
```
./install.sh
```

Then you need to launch node with (should be restarted every 5 minutes and between tests):

```
./fork.sh
```

Then you can run tests from `test` directory with:
```
npm run compile
npm run test
```

To see all kinds of logging, uncomment `console.log` lines in all `*.sol` files. You will need to set the block gas limit to 30M then in ganache-7.4.4/package.json "fork-celo" script.
