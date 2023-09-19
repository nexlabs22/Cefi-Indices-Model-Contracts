// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "../controller/ControllerInterface.sol";
import "./IndexFactoryInterface.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Index Token Factory
/// @author NEX Labs Protocol
/// @notice Allows User to initiate burn/mint requests and allows issuers to approve or deny them
contract IndexFactory is IndexFactoryInterface, OwnableUpgradeable, PausableUpgradeable {
    
    ControllerInterface public controller;

    address public usdc;
    uint8 public usdcDecimals;

    

    // mapping between a mint request hash and the corresponding request nonce.
    mapping(bytes32 => uint256) public mintRequestNonce;

    // mapping between a burn request hash and the corresponding request nonce.
    mapping(bytes32 => uint256) public burnRequestNonce;

    Request[] public mintRequests;
    Request[] public burnRequests;

    
    function initialize(address _controller, address _usdc, uint8 _usdcDecimals) external initializer {
        controller = ControllerInterface(_controller);

        usdc = _usdc;
        usdcDecimals = _usdcDecimals;

        __Ownable_init();
        __Pausable_init();

        transferOwnership(_controller);
    }

    
    modifier onlyMerchant() {
        require(controller.isMerchant(msg.sender), "sender not a merchant.");
        _;
    }

    modifier onlyIssuer() {
        require(controller.isIssuer(msg.sender), "sender not a issuer.");
        _;
    }

    function setUsdcAddress(address _usdc, uint8 _usdcDecimals) public onlyIssuer returns (bool){
        usdc = _usdc;
        usdcDecimals = _usdcDecimals;
        emit UsdcAddressSet(_usdc, _usdcDecimals, block.timestamp);
        return true;
    }
    
    

    function getAllMintRequests() public view returns(Request[] memory){
        return mintRequests;
    }

    function getAllBurnRequests() public view returns(Request[] memory){
        return burnRequests;
    }

    
    /// @notice Allows a user to initiate a mint request
    /// @param amount uint256
    /// @return bool
    function addMintRequest(
        uint256 amount
    ) external override whenNotPaused returns (uint256, bytes32) {
        
        //transfer usdc to custodian wallet
        address custodianWallet = controller.getCustodianWallet();
        SafeERC20.safeTransferFrom(IERC20(usdc), msg.sender, custodianWallet, amount);

        uint256 nonce = mintRequests.length;
        uint256 timestamp = getTimestamp();

        Request memory request = Request({
            requester: msg.sender,
            amount: amount,
            depositAddress: custodianWallet,
            nonce: nonce,
            timestamp: timestamp,
            status: RequestStatus.PENDING
        });

        bytes32 requestHash = calcRequestHash(request);
        mintRequestNonce[requestHash] = nonce;
        mintRequests.push(request);

        emit MintRequestAdd(nonce, msg.sender, amount, custodianWallet, timestamp, requestHash);
        return (nonce, requestHash);
    }

    /// @notice Allows a merchant to cancel a mint request
    /// @param requestHash bytes32
    /// @return bool
    function cancelMintRequest(bytes32 requestHash) external override onlyMerchant whenNotPaused returns (bool) {
        uint256 nonce;
        Request memory request;

        (nonce, request) = getPendingMintRequest(requestHash);

        require(msg.sender == request.requester, "cancel sender is different than pending request initiator");
        mintRequests[nonce].status = RequestStatus.CANCELED;

        emit MintRequestCancel(nonce, msg.sender, requestHash);
        return true;
    }

    address public rr;
    /// @notice Allows a issuer to confirm a mint request
    /// @param requestHash bytes32
    /// @return bool
    function confirmMintRequest(bytes32 requestHash, uint _tokenAmount) external override onlyIssuer returns (bool) {
        uint256 nonce;
        Request memory request;

        (nonce, request) = getPendingMintRequest(requestHash);
        rr = request.requester;
        mintRequests[nonce].status = RequestStatus.APPROVED;
        require(controller.mint(request.requester, _tokenAmount), "mint failed");


        emit MintConfirmed(
            request.nonce,
            request.requester,
            _tokenAmount,
            request.depositAddress,
            request.timestamp,
            requestHash
        );
        return true;
    }

    /// @notice Allows a issuer to reject a mint request
    /// @param requestHash bytes32
    /// @return bool
    function rejectMintRequest(bytes32 requestHash) external override onlyIssuer returns (bool) {
        uint256 nonce;
        Request memory request;

        (nonce, request) = getPendingMintRequest(requestHash);

        mintRequests[nonce].status = RequestStatus.REJECTED;

        emit MintRejected(
            request.nonce,
            request.requester,
            request.amount,
            request.depositAddress,
            request.timestamp,
            requestHash
        );
        return true;
    }

    
    /// @notice Allows a merchant to initiate a burn request
    /// @param amount uint256
    /// @return bool
    function burn(uint256 amount) external override whenNotPaused returns (bool) {
        address custodianWallet = controller.getCustodianWallet();
        uint256 nonce = burnRequests.length;
        uint256 timestamp = getTimestamp();

        Request memory request = Request({
            requester: msg.sender,
            amount: amount,
            depositAddress: msg.sender,
            nonce: nonce,
            timestamp: timestamp,
            status: RequestStatus.PENDING
        });

        bytes32 requestHash = calcRequestHash(request);
        burnRequestNonce[requestHash] = nonce;
        burnRequests.push(request);

        require(controller.burn(msg.sender, amount), "burn failed");

        emit Burned(nonce, msg.sender, amount, custodianWallet, timestamp, requestHash);
        return true;
    }

    
    /// @notice Allows a issuer to confirm a burn request
    /// @param requestHash bytes32
    /// @return bool
    function confirmBurnRequest(bytes32 requestHash) external override onlyIssuer returns (bool) {
        uint256 nonce;
        Request memory request;

        (nonce, request) = getPendingBurnRequest(requestHash);

        burnRequests[nonce].status = RequestStatus.APPROVED;

        emit BurnConfirmed(
            request.nonce,
            request.requester,
            request.amount,
            request.depositAddress,
            request.timestamp,
            requestHash
        );
        return true;
    }

    
    function pause() external override onlyOwner {
        _pause();
    }

    function unpause() external override onlyOwner {
        _unpause();
    }

    
    function getBurnRequestsLength() external view override returns (uint256 length) {
        return burnRequests.length;
    }

    /// @notice Gets a burn request by nonce
    /// @dev Returns the fields present in the request struct and also the request hash
    /// @param nonce uint256
    function getBurnRequest(uint256 nonce)
        external
        view
        override
        returns (
            uint256 requestNonce,
            address requester,
            uint256 amount,
            address depositAddress,
            uint256 timestamp,
            string memory status,
            bytes32 requestHash
        )
    {
        Request storage request = burnRequests[nonce];
        string memory statusString = getStatusString(request.status);

        requestNonce = request.nonce;
        requester = request.requester;
        amount = request.amount;
        depositAddress = request.depositAddress;
        timestamp = request.timestamp;
        status = statusString;
        requestHash = calcRequestHash(request);
    }

    /// @notice Gets a mint request by nonce
    /// @dev Returns the fields present in the request struct and also the request hash
    /// @param nonce uint256
    function getMintRequest(uint256 nonce)
        external
        view
        override
        returns (
            uint256 requestNonce,
            address requester,
            uint256 amount,
            address depositAddress,
            uint256 timestamp,
            string memory status,
            bytes32 requestHash
        )
    {
        Request memory request = mintRequests[nonce];
        string memory statusString = getStatusString(request.status);

        requestNonce = request.nonce;
        requester = request.requester;
        amount = request.amount;
        depositAddress = request.depositAddress;
        timestamp = request.timestamp;
        status = statusString;
        requestHash = calcRequestHash(request);
    }

    function getTimestamp() internal view returns (uint256) {
        // timestamp is only used for data maintaining purpose, it is not relied on for critical logic.
        return block.timestamp; // solhint-disable-line not-rely-on-time
    }

    function getPendingMintRequest(bytes32 requestHash) internal view returns (uint256 nonce, Request memory request) {
        require(requestHash != 0, "request hash is 0");
        nonce = mintRequestNonce[requestHash];
        request = mintRequests[nonce];
        validatePendingRequest(request, requestHash);
    }

    function getPendingBurnRequest(bytes32 requestHash) internal view returns (uint256 nonce, Request memory request) {
        require(requestHash != 0, "request hash is 0");
        nonce = burnRequestNonce[requestHash];
        request = burnRequests[nonce];
        validatePendingRequest(request, requestHash);
    }

    function getMintRequestsLength() external view override returns (uint256 length) {
        return mintRequests.length;
    }

    function validatePendingRequest(Request memory request, bytes32 requestHash) internal pure {
        require(request.status == RequestStatus.PENDING, "request is not pending");
        require(requestHash == calcRequestHash(request), "given request hash does not match a pending request");
    }

    function calcRequestHash(Request memory request) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    request.requester,
                    request.amount,
                    request.depositAddress,
                    request.nonce,
                    request.timestamp
                )
            );
    }

    function compareStrings(string memory a, string memory b) internal pure returns (bool) {
        return (keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b)));
    }

    function isEmptyString(string memory a) internal pure returns (bool) {
        return (compareStrings(a, ""));
    }

    function getStatusString(RequestStatus status) internal pure returns (string memory) {
        if (status == RequestStatus.PENDING) {
            return "pending";
        } else if (status == RequestStatus.CANCELED) {
            return "canceled";
        } else if (status == RequestStatus.APPROVED) {
            return "approved";
        } else if (status == RequestStatus.REJECTED) {
            return "rejected";
        } else {
            // this fallback can never be reached.
            return "unknown";
        }
    }
}