require('@nomiclabs/hardhat-waffle');
require("@nomiclabs/hardhat-etherscan");

const dotenv = require('dotenv');
dotenv.config();

task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();
  for (const account of accounts) {
    console.log(account.address);
  }
});

task("verify_contract","verifying all contract",async(taskArgs,hre) =>{
})


module.exports = {
    networks: {
    	testnet: {
      		url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      		chainId: 97,
      		accounts: [process.env.DEPLOYER_PRIVATE_KEY]
    	},
    	mainnet: {
      		url: "https://bsc-dataseed.binance.org/",
      		chainId: 56,
      		accounts: [process.env.DEPLOYER_PRIVATE_KEY]
    	},
    	localhost: {
      		url: "http://127.0.0.1:8545"
    	},
        bsc: {
            url: process.env.MAIN_NET_API_URL,
            accounts: [process.env.DEPLOYER_PRIVATE_KEY],
        },
        fork: {
            url: 'http://localhost:8545',
        },
        hardhat: {
            forking: {
                url: process.env.MAIN_NET_API_URL,
            }
        },
    },
    etherscan: {
        apiKey: process.env.BSCSCAN_API_KEY,
    },
    solidity: {
        version: "0.8.11",
        settings: {
            optimizer: {
                enabled: true,
                runs: 200,
            },
        },
    },
};