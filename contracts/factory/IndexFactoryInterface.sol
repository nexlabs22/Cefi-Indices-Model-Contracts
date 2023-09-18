// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

interface IndexFactoryInterface {
    event UsdcAddressSet(address indexed usdc, uint8 indexed decimals, uint time);

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
        address depositAddress; // issuer's asset address in mint, merchant's asset address in burn.
        uint256 nonce; // serial number allocated for each request.
        uint256 timestamp; // time of the request creation.
        RequestStatus status; // status of the request.
    }

    function pause() external;

    function unpause() external;

    function setIssuerDepositAddress(address merchant, address depositAddress) external returns (bool);

    function setMerchantDepositAddress(address depositAddress) external returns (bool);

    function setMerchantMintLimit(address merchant, uint256 amount) external returns (bool);

    function setMerchantBurnLimit(address merchant, uint256 amount) external returns (bool);

    function addMintRequest(
        uint256 amount,
        address depositAddress
    ) external returns (uint256);

    function cancelMintRequest(bytes32 requestHash) external returns (bool);

    function confirmMintRequest(bytes32 requestHash) external returns (bool);

    function rejectMintRequest(bytes32 requestHash) external returns (bool);

    function burn(uint256 amount) external returns (bool);

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
            address depositAddress,
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
            address depositAddress,
            uint256 timestamp,
            string memory status,
            bytes32 requestHash
        );
}