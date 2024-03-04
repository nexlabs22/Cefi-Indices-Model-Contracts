import { ethers } from "hardhat";

async function main() {

  const [deployer] = await ethers.getSigners();

  const requestNFT = await ethers.deployContract("RequestNFT", [
    "CRYPTO5 Request NFT",
    "CR5 NFT",
    deployer.address
  ]);

  await requestNFT.waitForDeployment();

  console.log(
    `RequestNFT deployed to ${requestNFT.target}`
  );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});