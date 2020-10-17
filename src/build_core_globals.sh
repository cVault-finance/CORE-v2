#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR

rm -rf tmp_contracts
mv contracts tmp_contracts
mkdir -p contracts/v612
cp tmp_contracts/v612/COREGlobals.sol contracts/v612/
rm -rf artifacts
rm -rf cache
yarn run buidler remove-logs
npx buidler compile
rm -rf contracts
mv tmp_contracts contracts
echo "Built COREGlobals.sol"