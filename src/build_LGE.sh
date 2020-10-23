#!/usr/bin/env bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd $DIR

rm -rf tmp_contracts
cp -R contracts tmp_contracts
# mkdir -p contracts/v612
rm -rf artifacts
rm -rf cache
yarn run buidler remove-logs
npx truffle-flattener contracts/v612/LGE.sol >> ./flattened_LGE.sol
rm -rf contracts
mkdir -p contracts/v612
mv ./flattened_LGE.sol contracts/v612/LGE.sol
pause
npx truffle compile
# mkdir -p flattened_sols
# function pause(){
#  read -s -n 1 -p "Press any key to continue . . ."
#  echo ""
# }
# pause
# npx truffle compile
# # npx oz deploy
# mv contracts/v612/flattened_LGE.sol flattened_sols
# rm -rf contracts
# mv tmp_contracts contracts
# echo "Built LGE.sol"