import { ethers } from "hardhat";
import {
    abi as Factory_ABI,
    bytecode as Factory_BYTECODE,
  } from '../artifacts/contracts/factory/IndexFactory.sol/IndexFactory.json'
import { IndexFactory } from "../typechain-types";
import { goerliAnfiFactory, goerliCrypto5Factory } from "../network";
require("dotenv").config()

async function main() {
    // const signer = new ethers.Wallet(process.env.PRIVATE_KEY as string)
    const [deployer] = await ethers.getSigners();
    // const signer = await ethers.getSigner(wallet)
    const provider = new ethers.JsonRpcProvider(process.env.GOERLI_RPC_URL)
    const cotract:any = new ethers.Contract(
        // goerliAnfiFactory, //factory goerli
        goerliCrypto5Factory, //factory goerli
        Factory_ABI,
        provider
    )
    // await wallet.connect(provider);
    console.log("sending data...")
    const result = await cotract.connect(deployer).mockFillAssetsList(
        ["0x914CC983F464E61883F11eEc9c86c3AF3B4A63c2","0xe98A6145acF43Fa2f159B28C70eB036A5Dc69409"],
        ["70000000000000000000", "30000000000000000000"]
        // ["3", "3"]
    )
    console.log("waiting for results...")
    const receipt = await result.wait();
    if(receipt.status ==1 ){
        console.log("success =>", receipt)
    }else{
        console.log("failed =>", receipt)
    }
}

main()