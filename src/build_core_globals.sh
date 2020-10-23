#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR

rm -rf tmp_contracts
cp -R contracts tmp_contracts
# mkdir -p contracts/v612
# cp tmp_contracts/v612/COREGlobals.sol contracts/v612/
rm -rf artifacts
rm -rf cache
yarn run buidler remove-logs
# npx truffle-flattener tmp_contracts/v612/COREGlobals.sol >> contracts/v612/flattened_COREGlobals.sol
rm flattened_COREGlobals.sol
npx truffle-flattener contracts/v612/COREGlobals.sol >> flattened_COREGlobals.sol
rm -rf contracts
mkdir -p contracts/v612
mv flattened_COREGlobals.sol contracts/v612/COREGlobals.sol
mkdir -p flattened_sols
function pause(){
 read -s -n 1 -p "Press any key to continue . . ."
 echo ""
}
pause
cp contracts/v612/COREGlobals.sol flattened_sols
npx buidler compile
rm -rf contracts
mv tmp_contracts contracts
echo "Built COREGlobals.sol"