# CORE-v2

## Running live tests

First, get an Infura Project ID (like an API key), and export it for your environment
```
export INFURAPID="abcdefghgjkl"
```

then...

```
# install jq
cd src
./build.sh
./startTestEnvironment.sh
# Now in a new tab/window…
./live_tests/test.sh
```

## Instructions

Visit src to review the contracts

To execute tests:

```
npx buidler test
```

Report bugs to dev@cvault.finance
