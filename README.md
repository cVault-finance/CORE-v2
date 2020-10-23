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


# LGE Live Update 1

changes:
- Renamed transferHandler() TransferHandler() in ICOREGlobals
- Changed ICORETransferHandler sync(address) to return (bool, bool)
- Use 1e18 for LPPerUnitContributed precision
- Changed claimLP function math to subtract the refund per person when transferring the LP to the contributor
- Added extendLGE function to allow LGEDurationDays to be increased by up to 24 hours at a time by either dev.
- Shuffle around how liquidity is added math to handle LP token contribution tokens not being counted on both sides.
- Added getCORERefundForPerson view to see how much someone's CORE refund is
- Use getCORERefundForPerson helper in the getCOREREfund method
- Minor spelling fixes
- In the addLiquidityToPair method, correct math calculating refund to divide by 1e18 instead of multiplying
- Added sanity check to addLiquidityToPair to make sure the total supply of the wrapped tokens are 0 after creating LP. Couldn't this happen because of dust?
- Store the LPPerUnitContributed at the end of addLiquidityToPair using 1e18 units of precision instead of 1e8
- Add sanity check that LPPerUnitContributed should be above zero to handle a multitude of potential errors
- Use the uppercase TransferHandler on core globals

