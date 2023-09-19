// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "../../contracts/test/Token.sol";
import "../../contracts/token/IndexToken.sol";
import "../../contracts/factory/IndexFactory.sol";
import "../../contracts/controller/Controller.sol";
import "../../contracts/factory/Members.sol";

contract CounterTest is Test {


    uint256 internal constant SCALAR = 1e20;

    struct Request {
        address requester; // sender of the request.
        uint256 amount; // amount of token to mint/burn.
        address depositAddress; // issuer's asset address in mint, merchant's asset address in burn.
        uint256 nonce; // serial number allocated for each request.
        uint256 timestamp; // time of the request creation.
        RequestStatus status; // status of the request.
    }

    enum RequestStatus {
        NULL,
        PENDING,
        CANCELED,
        APPROVED,
        REJECTED
    }

    Token public usdc;
    IndexToken public indexToken;
    Controller public controller;
    Members public members;
    IndexFactory public factory;

    address deployer = vm.addr(1);
    address custodianWallet = vm.addr(2);
    address issuer = vm.addr(3);
    address merchant = vm.addr(4);
    address feeReceiver = vm.addr(5);
    address minter = vm.addr(6);

    address add1 = vm.addr(7);
    address add2 = vm.addr(8);
    address add3 = vm.addr(9);
    address add4 = vm.addr(10);


    function setUp() public {
        usdc = new Token(
            1000000e6
        );
        members = new Members(
            address(this)
        );
        indexToken = new IndexToken();
        indexToken.initialize(
            "Anti Inflation",
            "ANFI",
            1e18,
            feeReceiver,
            1000000e18
        );
        controller = new Controller();
        controller.initialize(
            address(indexToken)
        );
        factory = new IndexFactory();
        factory.initialize(
            address(controller),
            address(usdc),
            6
        );
        

        members.setCustodianWallet(custodianWallet);
        members.setIssuer(issuer);
        members.addMerchant(merchant);
        controller.setMembers(address(members));
        indexToken.setMinter(address(controller));
        controller.setFactory(address(factory));
    }

    function testInitialized() public {
        assertEq(address(factory.controller()), address(controller));
        assertEq(factory.owner(), address(controller));
        assertEq(address(factory.usdc()), address(usdc));
        assertEq(factory.usdcDecimals(), 6);
        assertEq(address(controller.factory()), address(factory));
        assertEq(members.custodianWallet(), custodianWallet);
        assertEq(controller.getCustodianWallet(), custodianWallet);
        assertEq(members.issuer(), issuer);
        assertEq(members.isMerchant(merchant), true);
    }


    function testMintTokens() public {
        IndexFactory.Request[] memory mintRequests = factory.getAllMintRequests();
        assertEq(mintRequests.length, 0);
        usdc.transfer(add1, 1000e6);
        vm.startPrank(add1);
        usdc.approve(address(factory), 1000e6);
        (uint nonce, bytes32 requestHash) = factory.addMintRequest(1000e6);
        //check results
        mintRequests = factory.getAllMintRequests();
        assertEq(mintRequests[0].requester, add1);
        assertEq(mintRequests[0].amount, 1000e6);
        assertEq(mintRequests[0].depositAddress, custodianWallet);
        assertEq(mintRequests[0].nonce, 0);
        assertEq(mintRequests[0].timestamp, block.timestamp);
        assertEq(mintRequests.length, 1);
        assertEq(usdc.balanceOf(custodianWallet), 1000e6);
        assertEq(factory.mintRequestNonce(requestHash), nonce);
        vm.stopPrank();
        //conform mint request
        vm.startPrank(issuer);
        factory.confirmMintRequest(requestHash, 10e18);
        //check results
        assertEq(indexToken.balanceOf(add1), 10e18);        
    }

    

    
}
