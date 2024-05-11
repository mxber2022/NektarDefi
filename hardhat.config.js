require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  defaultNetwork: "hardhat",

  networks: { 
    hardhat: {
      chainId: 31337,
      forking: {
        url: "https://mainnet.infura.io/v3/1cd853bc10304f8ba6faa52343f86aac"
      }
    }
  }
};