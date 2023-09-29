// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "../../contracts/test/Token.sol";
import "../../contracts/token/IndexToken.sol";
import "../../contracts/token/RequestNFT.sol";
import "../../contracts/factory/IndexFactory.sol";
import "../../contracts/factory/IndexFactoryInterface.sol";

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

    event IssuerSet(address indexed issuer);

    event CustodianSet(address indexed custodian);

    event UsdcAddressSet(address indexed usdc, uint8 indexed decimals, uint time);

    event TokenAddressSet(address indexed token, uint time);

    event IssuerDepositAddressSet(address indexed merchant, address indexed sender, address depositAddress);

    event MerchantDepositAddressSet(address indexed merchant, address depositAddress);

    event MintRequestAdd(
        uint256 indexed nonce,
        address indexed requester,
        uint256 amount,
        address depositAddress,
        uint256 timestamp,
        bytes32 requestHash
    );

    event MintRequestCancel(uint256 indexed nonce, address indexed requester, bytes32 requestHash);

    event MintConfirmed(
        uint256 indexed nonce,
        address indexed requester,
        uint256 amount,
        address depositAddress,
        uint256 timestamp,
        bytes32 requestHash
    );

    event MintRejected(
        uint256 indexed nonce,
        address indexed requester,
        uint256 amount,
        address depositAddress,
        uint256 timestamp,
        bytes32 requestHash
    );

    event Burned(
        uint256 indexed nonce,
        address indexed requester,
        uint256 amount,
        address depositAddress,
        uint256 timestamp,
        bytes32 requestHash
    );

    event BurnConfirmed(
        uint256 indexed nonce,
        address indexed requester,
        uint256 amount,
        address depositAddress,
        uint256 timestamp,
        bytes32 inputRequestHash
    );

    Token public usdc;
    Token public newUsdc;
    IndexToken public indexToken;
    IndexToken public newIndexToken;
    RequestNFT public nft;
    RequestNFT public newNft;
    IndexFactory public factory;
    IndexFactory public newFactory;

    address deployer = vm.addr(1);
    address custodianWallet = vm.addr(2);
    address newCustodianWallet = vm.addr(3);
    address issuer = vm.addr(4);
    address newIssuer = vm.addr(5);
    address merchant = vm.addr(6);
    address newMerchant = vm.addr(7);
    address feeReceiver = vm.addr(8);
    address minter = vm.addr(9);

    address add1 = vm.addr(10);
    address add2 = vm.addr(11);
    address add3 = vm.addr(12);
    address add4 = vm.addr(13);


    function setUp() public {
        usdc = new Token(
            1000000e6
        );
        newUsdc = new Token(
            1000000e6
        );
        indexToken = new IndexToken();
        indexToken.initialize(
            "Anti Inflation",
            "ANFI",
            1e18,
            feeReceiver,
            1000000e18
        );
        nft = new RequestNFT(
             "ANFI NFT",
             "ANFI NFT",
             address(0)
        );
        newNft = new RequestNFT(
             "ANFI NFT",
             "ANFI NFT",
             address(0)
        );
        newIndexToken = new IndexToken();
        newIndexToken.initialize(
            "Anti Inflation",
            "ANFI",
            1e18,
            feeReceiver,
            1000000e18
        );
        factory = new IndexFactory();
        factory.initialize(
            custodianWallet,
            issuer,
            address(indexToken),
            address(usdc),
            6,
            address(nft)
        );
        newFactory = new IndexFactory();
        newFactory.initialize(
            custodianWallet,
            issuer,
            address(indexToken),
            address(usdc),
            6,
            address(nft)
        );
        

        indexToken.setMinter(address(factory));
        nft.setMinter(address(factory));
    }

    function testInitialized() public {
        assertEq(factory.owner(), address(this));
        assertEq(address(factory.token()), address(indexToken));
        assertEq(factory.custodianWallet(), custodianWallet);
        assertEq(factory.issuer(), issuer);
        assertEq(address(factory.usdc()), address(usdc));
        assertEq(factory.usdcDecimals(), 6);
    }


    



    function testMintNFTTokens() public {
        IndexFactory.Request[] memory mintRequests = factory.getAllMintRequests();
        assertEq(mintRequests.length, 0);
        usdc.transfer(add1, 1000e6);
        vm.startPrank(add1);
        usdc.approve(address(factory), 1000e6);
        (uint nonce, bytes32 requestHash) = factory.addMintRequest(1000e6);
        //check results
        assertEq(nft.balanceOf(add1), 1);
        assertEq(nft.totalSupply(), 2);
        assertEq(factory.mintRequestNonce(requestHash), nonce);
        mintRequests = factory.getAllMintRequests();
        assertEq(mintRequests.length, 1);
        assertEq(mintRequests[nonce].requester, add1);
        assertEq(mintRequests[nonce].amount, 1000e6);
        assertEq(mintRequests[nonce].depositAddress, custodianWallet);
        assertEq(mintRequests[nonce].nonce, 0);
        assertEq(mintRequests[nonce].timestamp, block.timestamp);
        assertEq(mintRequests[nonce].status == IndexFactoryInterface.RequestStatus.PENDING, true);
        assertEq(mintRequests.length, 1);
        assertEq(usdc.balanceOf(custodianWallet), 1000e6);
        assertEq(factory.mintRequestNonce(requestHash), nonce);
        vm.stopPrank();
        //conform mint request
        vm.startPrank(issuer);
        factory.confirmMintRequest(requestHash, 10e18);
        //check results
        mintRequests = factory.getAllMintRequests();
        assertEq(mintRequests[nonce].status == IndexFactoryInterface.RequestStatus.APPROVED, true);
        assertEq(indexToken.balanceOf(add1), 10e18);
    }


    


    function testNFTBurnTokens() public {
        IndexFactory.Request[] memory mintRequests = factory.getAllMintRequests();
        IndexFactory.Request[] memory burnRequests = factory.getAllBurnRequests();
        assertEq(mintRequests.length, 0);
        usdc.transfer(add1, 1000e6);
        vm.startPrank(add1);
        //add mint request
        usdc.approve(address(factory), 1000e6);
        (uint nonce, bytes32 requestHash) = factory.addMintRequest(1000e6);
        //check results
        assertEq(nft.balanceOf(add1), 1);
        assertEq(nft.totalSupply(), 2);
        assertEq(factory.mintRequestNonce(requestHash), nonce);
        mintRequests = factory.getAllMintRequests();
        assertEq(mintRequests[nonce].requester, add1);
        assertEq(mintRequests[nonce].amount, 1000e6);
        assertEq(mintRequests[nonce].depositAddress, custodianWallet);
        assertEq(mintRequests[nonce].nonce, 0);
        assertEq(mintRequests[nonce].timestamp, block.timestamp);
        assertEq(mintRequests[nonce].status == IndexFactoryInterface.RequestStatus.PENDING, true);
        assertEq(mintRequests.length, 1);
        assertEq(usdc.balanceOf(custodianWallet), 1000e6);
        assertEq(factory.mintRequestNonce(requestHash), nonce);
        vm.stopPrank();
        //conform mint request
        vm.startPrank(issuer);
        factory.confirmMintRequest(requestHash, 10e18);
        //check results
        mintRequests = factory.getAllMintRequests();
        assertEq(mintRequests[nonce].status == IndexFactoryInterface.RequestStatus.APPROVED, true);
        assertEq(indexToken.balanceOf(add1), 10e18);
        vm.stopPrank();

        //add burn request
        vm.startPrank(add1);
        (uint burnNonce, bytes32 burnRequestHash) = factory.burn(10e18);
        //check results
        assertEq(factory.burnRequestNonce(burnRequestHash), burnNonce);
        burnRequests = factory.getAllBurnRequests();
        assertEq(burnRequests[burnNonce].requester, add1);
        assertEq(burnRequests[burnNonce].amount, 10e18);
        assertEq(burnRequests[burnNonce].depositAddress, add1);
        assertEq(burnRequests[burnNonce].nonce, burnNonce);
        assertEq(burnRequests[burnNonce].timestamp, block.timestamp);
        assertEq(burnRequests[burnNonce].status == IndexFactoryInterface.RequestStatus.PENDING, true);
        assertEq(indexToken.balanceOf(add1), 0);
        vm.stopPrank();
        //conform mint request
        vm.startPrank(issuer);
        factory.confirmBurnRequest(burnRequestHash);
        //check results
        burnRequests = factory.getAllBurnRequests();
        assertEq(burnRequests[burnNonce].requester, add1);
        assertEq(burnRequests[burnNonce].amount, 10e18);
        assertEq(burnRequests[burnNonce].depositAddress, add1);
        assertEq(burnRequests[burnNonce].nonce, burnNonce);
        assertEq(burnRequests[burnNonce].timestamp, block.timestamp);
        assertEq(burnRequests[burnNonce].status == IndexFactoryInterface.RequestStatus.APPROVED, true);
        assertEq(indexToken.balanceOf(add1), 0);
    }

    
}
