#!/usr/bin/env bash
echo "Make sure you have jq installed (brew install jq on a mac)"
BLOCK_DATA=`curl -X POST --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":83}' https://mainnet.infura.io/v3/$INFURAPID | jq -r .result`
CLEANED_BLOCK_NUM=${BLOCK_DATA//0x/}
BLOCK_DECIMAL=$(printf "%d\n" $((16#$CLEANED_BLOCK_NUM)))

ARGS="--chainId 1 --callGasLimit 0x1fffffffffffff --keepAliveTimeout 50000 --noVMErrorsOnRPCResponse  --gasPrice 0 --allowUnlimitedContractSize -l 4503599627370495 --unlock 0x5A16552f59ea34E44ec81E58b3817833E9fD5436 --unlock 0xca06411bd7a7296d7dbdd0050dfc846e95febeb7 --unlock 0x000000000000000000000000000000000000dEaD --unlock 0xd5b47B80668840e7164C1D1d81aF8a9d9727B421 -m lift pottery popular bid consider dumb faculty better alpha mean game attack  "
CMD="npx ganache-cli   --fork https://mainnet.infura.io/v3/$INFURAPID@$BLOCK_DECIMAL $ARGS"
$CMD

#https://medium.com/ethereum-grid/forking-ethereum-mainnet-mint-your-own-dai-d8b62a82b3f7
#look in to unlock function
#https://github.com/ryanio/truffle-mint-dai/blob/master/test/dai.js
#some example tests