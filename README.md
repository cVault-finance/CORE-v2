# CORE-v2
## Project links and info

Website links and redundant links
Service #1 is online at https://www.cvault.finance/
Service #2 is online at https://gateway.pinata.cloud/ipfs/QmXRez85MNjxRpBNMtTq65CWv5tZE1AgGuAZxevqZ83d5P/
Service #3 is available at https://win95.cvault.finance/
Service #4 is available at https://cvault.finance/
Service #5 is available at http://core-www-nfce9g5ol.vercel.app/

### Official Twitter accounts
Main twitter
https://twitter.com/CORE_Vault
Developers
https://twitter.com/0xRevert/
https://twitter.com/x3devships
Head of ops
https://twitter.com/0xdec4f

### Telegram channels
Main:
https://t.me/COREVault
Trading chats :
Price talk
https://t.me/coretradingchat
LP trading
https://t.me/corelptrade
NSFW/4chan contaiment trading
https://t.me/joinchat/Qq12vEY-zHHb8V0R76zrhA
Puzzle chat
https://t.me/corepuzzle
Developer chat
https://t.me/coredevchat
Technical support
https://t.me/coretechsupport
Fork discussion
https://t.me/shitCoreFork

### Discord :
https://discord.com/invite/hPUm9Jh

### Github repositories
https://github.com/cVault-finance

### Documentation
https://help.cvault.finance/

### ndepth farming information
https://www.corefarming.info/


### Audits
https://twitter.com/TheArcadiaGroup/status/1314370021154590721

### Articles
Official
ERC95: A New Standard
https://medium.com/core-vault/erc95-a-new-standard-e59e806b7d82

The idea, project and vision of CORE Vault
https://medium.com/@0xdec4f/the-idea-project-and-vision-of-core-vault-52f5eddfbfb

5 Things You Did Not Know About CORE
https://0xdec4f.medium.com/5-things-you-did-not-know-about-core-4bfe3d8b1452

### LGE2 Articles

CORE: Liquidity Generation Event #2
Growing CORE and its Ecosystem
https://medium.com/core-vault/core-liquidity-generation-event-2-4c2f8df391ce

FAQ: LGE #2
Questions and Answers regarding the upcoming Liquidity Generation Event
https://medium.com/core-vault/faq-lge-2-cb425e625135

Empowering a true DeFi economy with Bitcoin
https://medium.com/core-vault/empowering-a-true-defi-economy-with-bitcoin-97981359d69a

LGE #2: How to contribute your tokens
https://medium.com/core-vault/lge-2-how-to-approve-your-tokens-62897c966512

The unique Advantages of Liquidity Generation Events
https://medium.com/core-vault/the-unique-advantages-of-liquidity-generation-events-e3136fb9cc10

LGE#2 Final Day: What happens Next?
https://medium.com/core-vault/lge-2-final-day-what-happens-next-c4f276b164cc

[UPDATED] LGE #2: How to stake your LP tokens using etherscan.io
https://medium.com/core-vault/lge-2-how-to-stake-your-lp-tokens-using-etherscan-io-6cad7bdde823

### 3rd party Articles
http://goran.krampe.se/category/core/




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

