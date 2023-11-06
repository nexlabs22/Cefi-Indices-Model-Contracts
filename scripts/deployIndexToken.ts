import { ethers, upgrades } from "hardhat";
// const { ethers, upgrades, network, hre } = require('hardhat');

async function deployIndexToken() {
  
  const [deployer] = await ethers.getSigners();

  const IndexToken = await ethers.getContractFactory("IndexToken");
  console.log('Deploying IndexToken...');

  const indexToken = await upgrades.deployProxy(IndexToken, [
      "CRYPTO5 Index token",
      "CR5",
      '1000000000000000000', // 1e18
      deployer.address,
      '1000000000000000000000000' // 1000000e18
  ], { initializer: 'initialize' });

  await indexToken.waitForDeployment()

  console.log(
    `IndexToken deployed: ${ await indexToken.getAddress()}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
deployIndexToken().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
