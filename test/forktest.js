const hre = require("hardhat");
const { ethers } = require("ethers")

const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545/");

async function main() {
    
    const wallet = new ethers.Wallet("0xdf57089febbacf7ba0bc227dafbffa9fc08a93fdc68e1e42411a14efcf23656e");
    const connectedWallet = wallet.connect(provider);

    /* 
        Mint/Deposit DivaEtherToken script
    */

    const DivaTokenAddress = "0x78Cb3BE3ee9C7aD14967aD10F9D2baFA79F2DC94";
    const abi = [

    ]
    const CONTRACT = new ethers.Contract(DivaTokenAddress, abi, provider);

    /* 
        2. Supply token on aave
    */
    const PoolAbi = [
        {
          "inputs": [
            {
              "internalType": "address",
              "name": "asset",
              "type": "address"
            },
            {
              "internalType": "uint256",
              "name": "amount",
              "type": "uint256"
            },
            {
              "internalType": "address",
              "name": "onBehalfOf",
              "type": "address"
            },
            {
              "internalType": "uint16",
              "name": "referralCode",
              "type": "uint16"
            }
          ],
          "name": "supply",
          "outputs": [],
          "stateMutability": "nonpayable",
          "type": "function"
        },
        
        {
            "inputs": [
              {
                "internalType": "address",
                "name": "asset",
                "type": "address"
              },
              {
                "internalType": "uint256",
                "name": "amount",
                "type": "uint256"
              },
              {
                "internalType": "uint256",
                "name": "interestRateMode",
                "type": "uint256"
              },
              {
                "internalType": "uint16",
                "name": "referralCode",
                "type": "uint16"
              },
              {
                "internalType": "address",
                "name": "onBehalfOf",
                "type": "address"
              }
            ],
            "name": "borrow",
            "outputs": [],
            "stateMutability": "nonpayable",
            "type": "function"
          }
    ];
      
    const aavePoolAddress = "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2";
    const PoolContract =  new ethers.Contract(aavePoolAddress, PoolAbi, provider);
    const txsupply = await PoolContract.connect(connectedWallet).supply("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 1, "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199", 0);
    const receipt = await tx.wait()
    console.log("receipt:", receipt);

    /*
        3. Borrow token on aave
    */
      
    const txborrow = await PoolContract.connect(connectedWallet).supply("0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 1, "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199", 0);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});