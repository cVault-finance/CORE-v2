#!/usr/bin/env bash
cd "${0%/*}"
# npx buidler test tests_live/live.test.js --network localhost
#npx hardhat test --show-stack-traces --network ganache tests_live/live.test.js
npx hardhat test --show-stack-traces --network hardhat tests_live/live.test.js
