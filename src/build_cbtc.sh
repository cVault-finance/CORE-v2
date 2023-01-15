#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR

rm -rf tmp_contracts
cp -R contracts tmp_contracts
rm -rf artifacts
rm -rf cache
rm -rf build
mkdir -p flattened_sols
rm flattened_sols/flattened_cBTC.sol
yarn run hardhat remove-logs
function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}
npx truffle-flattener contracts/v612/cBTC.sol >> flattened_sols/flattened_cBTC.sol
pause
rm -rf contracts
mkdir -p contracts/v612
cp flattened_sols/flattened_cBTC.sol contracts/v612/cBTC.sol
echo "It would be wise to try npx oz deploy at this step if there is a contract in here being deployed behind a proxy. But make sure not to use the truffle output. Buidler output goes in /artifacts"
pause
npx hardhat compile
rm -rf contracts
mv tmp_contracts contracts
echo "Built cBTC.sol"