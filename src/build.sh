#!/usr/bin/env bash
rm -rf cache
rm -rf artifacts
echo "Building v4.2.4 contracts"
npx hardhat compile --config v424.buidler.config.js
echo "Building v5.0.0 contracts"
npx hardhat compile --config v500.buidler.config.js
echo "Building v6.12.0 contracts"
npx hardhat compile
#npx buidler test
