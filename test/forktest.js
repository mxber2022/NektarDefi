const hre = require("hardhat");
const { ethers } = require("ethers")
const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545/");
const provider_ss = new ethers.JsonRpcProvider("https://sepolia.infura.io/v3/1cd853bc10304f8ba6faa52343f86aac");

const routerArtifact = require('@uniswap/v2-periphery/build/UniswapV2Router02.json')
const erc20Abi = require("./erc20.json")
const wethArtifact = require("./weth.json")


const WETH_ADDRESS = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
const USDT_ADDRESS = '0xdAC17F958D2ee523a2206206994597C13D831ec7'
const ROUTER_ADDRESS = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D'
const PAIR_ADDRESS = '0x0d4a11d5eeaac28ec3f61d100daf4d40471f1852'


async function main() {
    
    const wallet = new ethers.Wallet("0xdf57089febbacf7ba0bc227dafbffa9fc08a93fdc68e1e42411a14efcf23656e");
    const connectedWallet = wallet.connect(provider);
    const signer = wallet.connect(provider)

    /*
        Swap token uniswap
    */
        
        const router = new ethers.Contract(ROUTER_ADDRESS, routerArtifact.abi, provider)
        const usdt = new ethers.Contract(USDT_ADDRESS, erc20Abi, provider)
        const weth = new ethers.Contract(WETH_ADDRESS, wethArtifact.abi, provider)

        const ethBalance = await provider.getBalance(signer.address)
        const usdtBalance = await usdt.balanceOf(signer.address)
        const wethBalance = await weth.balanceOf(signer.address)

        console.log('ETH Balance:', ethers.formatUnits(ethBalance, 18))
        console.log('WETH Balance:', ethers.formatUnits(wethBalance, 18))
        console.log('USDT Balance:', ethers.formatUnits(usdtBalance, 6))

        let nounce = await provider.getTransactionCount(signer.address);
        console.log("nounce: ", nounce);

        await signer.sendTransaction({
            to: WETH_ADDRESS,
            value: ethers.parseUnits('5', 18),
            nonce: nounce
        })

        nounce++;
        const amountIn = ethers.parseUnits('1', 18)
        const tx1 = await weth.connect(signer).approve(router.target, amountIn, {
            nonce: nounce
        })
        tx1.wait()
        nounce++;
        const tx2 = await router.connect(signer).swapExactTokensForTokens(
            amountIn,
            0,
            [WETH_ADDRESS, USDT_ADDRESS],
            signer.address,
            Math.floor(Date.now() / 1000) + (60 * 10),
            {
                gasLimit: 1000000,
                nonce: nounce
            },
        )
        await tx2.wait()

        console.log("_______________________________________________");
        console.log('ETH Balance after swap:', ethers.formatUnits(ethBalance, 18))
        console.log('WETH Balance after swap:', ethers.formatUnits(wethBalance, 18))
        console.log('USDT Balance after swap:', ethers.formatUnits(usdtBalance, 6))





        nounce++;

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

    // token approval
    const amountInx = ethers.parseUnits('1', 18)
    const tx1x = await weth.connect(signer).approve("0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2", amountInx)
    tx1x.wait()
    console.log("Approved Aave Pool contract to spend the token");
      
    const aavePoolAddress = "0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2";
    const PoolContract =  new ethers.Contract(aavePoolAddress, PoolAbi, provider);
    nounce++;
    const txsupply = await PoolContract.connect(connectedWallet).supply(
        "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 
        amountInx, 
        "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199", 
        0, 
        {
            gasLimit: 1000000,
            nonce: nounce
        });
    const receipt = await txsupply.wait()
    console.log("borrow receipt:", receipt);   
    
    nounce ++





    /*
        3. Borrow token on aave
    */
    const txborrow = await PoolContract.connect(connectedWallet).borrow(
        "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2", 
        amountInx, 
        2, 
        0,
        "0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199", 
        {
        gasLimit: 1000000,
        nonce: nounce
    });
    const receiptBorrow = await txborrow.wait()
    console.log("receipt:", receiptBorrow);      
    






    /* 
        Sepolia Mint/Deposit DivaEtherToken script
    */

        const DivaTokenAddressSepolia = "0x78Cb3BE3ee9C7aD14967aD10F9D2baFA79F2DC94";
        const DepositAbi = [
            {
                "inputs": [],
                "name": "deposit",
                "outputs": [
                    {
                        "internalType": "uint256",
                        "name": "shares",
                        "type": "uint256"
                    }
                ],
                "stateMutability": "payable",
                "type": "function"
            }
        ];
        const wallet1 = new ethers.Wallet("d2ab6e77539c6d2ba90f19b217e26e4fad301e5066445514b4b63cba0fc80b6c");
        const connectedWallet1 = wallet1.connect(provider_ss);
        const CONTRACTDeposit = new ethers.Contract(DivaTokenAddressSepolia, DepositAbi, provider_ss);
        const txdeposit = await CONTRACTDeposit.connect(connectedWallet1).deposit({
            value: ethers.parseEther("0.001"), // Example: sending 1 Ether
            gasLimit: "4000000"
        });
        console.log("txdeposit: ", txdeposit);
    
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});


function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}