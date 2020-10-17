const { ethers, Wallet, ContractFactory, Provider } = require("ethers");
const fs = require('fs');

const unpackArtifact = (artifactPath) => {
    let contractData = JSON.parse(fs.readFileSync(artifactPath))
    const contractBytecode = contractData['bytecode']
    const contractABI = contractData['abi']
    const constructorArgs = contractABI.filter((itm) => {
        return itm.type == 'constructor'
    })
    let constructorStr;
    if(constructorArgs.length < 1) {
        constructorStr = "    -- No constructor arguments -- "
    }
    else {
        constructorJSON = constructorArgs[0].inputs
        constructorStr = JSON.stringify(constructorJSON.map((c) => {
            return {
                name: c.name,
                type: c.type
            }
        }))
    }
    return {
        abi: contractABI,
        bytecode: contractBytecode,
        description:`  ${contractData.contractName}\n    ${constructorStr}`
    }
}

const deployTokenFromSigner = (contractABI, contractBytecode, args = []) => {
    const factory = new ContractFactory(contractABI, contractBytecode)
    let deployTx = factory.getDeployTransaction(...args)
    console.log(deployTx)
}

const deploycBTC = () => {
    let unpacked = unpackArtifact("./artifacts/cBTC.json")
    // constructor(address[] memory _addresses, uint8[] memory _percent, uint8[] memory tokenDecimals,  address _coreGlobals)
    let args = [
        ["0x2260fac5e5542a773aa44fbcfedf7c193bc2c599"],
        [100],
        [8],
        "0x255CA4596A963883Afe0eF9c85EA071Cc050128B"
    ]
    deployTokenFromSigner(unpacked.abi, unpacked.bytecode, args);
}

deploycBTC();
