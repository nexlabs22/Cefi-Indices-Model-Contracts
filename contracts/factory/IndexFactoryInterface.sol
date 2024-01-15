// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface IndexFactoryInterface {

    event IssuerSet(address indexed issuer);

    event NFTSet(address indexed nft);

    event CustodianSet(address indexed custodian);

    event UsdcAddressSet(address indexed usdc, uint8 indexed decimals, uint time);

    event TokenAddressSet(address indexed token, uint time);

    event IssuerDepositAddressSet(address indexed merchant, address indexed sender, address depositAddress);

    event MerchantDepositAddressSet(address indexed merchant, address depositAddress);

    event MintRequestAdd(
        uint256 indexed nonce,
        address indexed requester,
        uint256 amount,
        address[] depositAddresses,
        uint256 timestamp,
        bytes32 requestHash
    );

    event MintRequestCancel(uint256 indexed nonce, address indexed requester, bytes32 requestHash);

    event MintConfirmed(
        uint256 indexed nonce,
        address indexed requester,
        uint256 amount,
        address[] depositAddresses,
        uint256 timestamp,
        bytes32 requestHash
    );

    event MintRejected(
        uint256 indexed nonce,
        address indexed requester,
        uint256 amount,
        address[] depositAddresses,
        uint256 timestamp,
        bytes32 requestHash
    );

    event Burned(
        uint256 indexed nonce,
        address indexed requester,
        uint256 amount,
        address[] depositAddresses,
        uint256 timestamp,
        bytes32 requestHash
    );

    event BurnConfirmed(
        uint256 indexed nonce,
        address indexed requester,
        uint256 amount,
        address[] depositAddresses,
        uint256 timestamp,
        bytes32 inputRequestHash
    );

    ///=============================================================================================
    /// Data Structres
    ///=============================================================================================

    enum RequestStatus {
        NULL,
        PENDING,
        CANCELED,
        APPROVED,
        REJECTED
    }

    struct Request {
        address requester; // sender of the request.
        uint256 amount; // amount of token to mint/burn.
        address[] depositAddresses; // issuer's asset address in mint, merchant's asset address in burn.
        uint256 nonce; // serial number allocated for each request.
        uint256 timestamp; // time of the request creation.
        RequestStatus status; // status of the request.
    }

    function pause() external;

    function unpause() external;

    
    function addMintRequest(
        uint256 amount,
        address user
    ) external returns (uint256, bytes32);


    function confirmMintRequest(bytes32 requestHash, uint _tokenAmount) external returns (bool);


    function burn(uint256 amount, address user) external returns (uint256, bytes32);

    function confirmBurnRequest(bytes32 requestHash) external returns (bool);

    function getMintRequestsLength() external view returns (uint256 length);

    function getBurnRequestsLength() external view returns (uint256 length);

    function getBurnRequest(uint256 nonce)
        external
        view
        returns (
            uint256 requestNonce,
            address requester,
            uint256 amount,
            address[] memory depositAddresses,
            uint256 timestamp,
            string memory status,
            bytes32 requestHash
        );

    function getMintRequest(uint256 nonce)
        external
        view
        returns (
            uint256 requestNonce,
            address requester,
            uint256 amount,
            address[] memory depositAddresses,
            uint256 timestamp,
            string memory status,
            bytes32 requestHash
        );

    function setTokenAddress(address _token) external returns (bool);
    function setUsdcAddress(address _usdc, uint8 _usdcDecimals) external returns (bool);
    function setCustodianWallet(address _custodianWallet) external returns (bool);
    function setIssuer(address _issuer) external returns (bool);

}