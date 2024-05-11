const hre = require("hardhat");
const { ethers } = require("ethers")

const provider = new ethers.JsonRpcProvider("http://127.0.0.1/8545");

async function main() {
    
    const accounts = await hre.ethers.getSigners();

    /* 
    
    */

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});