#!/usr/bin/sh

cd ethereumjs-monorepo--ethereumjs-vm-5.9.3
npm run clean
cd ..
cd ganache-7.4.4
npm run clean
cd ..
cd test
rm -rf node_modules build
