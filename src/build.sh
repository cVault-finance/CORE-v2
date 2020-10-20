#!/usr/bin/env bash
echo "Building v4.2.4 contracts"
npx buidler compile --config v424.buidler.config.js
echo "Building v5.0.0 contracts"
npx buidler compile --config v500.buidler.config.js
echo "Building v6.12.0 contracts"
npx buidler compile
#npx buidler test
