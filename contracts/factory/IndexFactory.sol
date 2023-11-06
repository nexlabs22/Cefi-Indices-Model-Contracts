// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "./IndexFactoryInterface.sol";
import "../token/IndexToken.sol";
import "../token/RequestNFT.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Index Token Factory
/// @author NEX Labs Protocol
/// @notice Allows User to initiate burn/mint requests and allows issuers to approve or deny them
contract IndexFactory is
    IndexFactoryInterface,
    OwnableUpgradeable,
    PausableUpgradeable
{
    IndexToken public token;

    address public custodianWallet;
    address public issuer;

    address public usdc;
    uint8 public usdcDecimals;

    uint8 public feeRate; // 10/10000 = 0.1%
    uint256 public latestFeeUpdate;



    // mapping between a mint request hash and the corresponding request nonce.
    mapping(bytes32 => uint256) public mintRequestNonce;

    // mapping between a burn request hash and the corresponding request nonce.
    mapping(bytes32 => uint256) public burnRequestNonce;

    Request[] public mintRequests;
    Request[] public burnRequests;

    RequestNFT public nft;

    function initialize(
        address _custodianWallet,
        address _issuer,
        address _token,
        address _usdc,
        uint8 _usdcDecimals,
        address _nft
    ) external initializer {
        custodianWallet = _custodianWallet;
        issuer = _issuer;
        token = IndexToken(_token);
        usdc = _usdc;
        usdcDecimals = _usdcDecimals;
        nft = RequestNFT(_nft);
        __Ownable_init();
        __Pausable_init();
        feeRate = 10;
    }

    modifier onlyIssuer() {
        require(msg.sender == issuer, "sender not a issuer.");
        _;
    }

//Notice: newFee should be between 1 to 100 (0.01% - 1%)
  function setFeeRate(uint8 _newFee) public onlyOwner {
    uint256 distance = block.timestamp - latestFeeUpdate;
    require(distance / 60 / 60 > 12, "You should wait at least 12 hours after the latest update");
    require(_newFee <= 100 && _newFee >= 1, "The newFee should be between 1 and 100 (0.01% - 1%)");
    feeRate = _newFee;
    latestFeeUpdate = block.timestamp;
  }

    function setUsdcAddress(
        address _usdc,
        uint8 _usdcDecimals
    ) public override onlyOwner returns (bool) {
        require(_usdc != address(0), "invalid token address");
        usdc = _usdc;
        usdcDecimals = _usdcDecimals;
        emit UsdcAddressSet(_usdc, _usdcDecimals, block.timestamp);
        return true;
    }

    function setTokenAddress(
        address _token
    ) public override onlyOwner returns (bool) {
        require(_token != address(0), "invalid token address");
        token = IndexToken(_token);
        emit TokenAddressSet(_token, block.timestamp);
        return true;
    }

    function setCustodianWallet(address _custodianWallet) external override onlyOwner returns (bool) {
        require(_custodianWallet != address(0), "invalid custodian wallet address");
        custodianWallet = _custodianWallet;
        emit CustodianSet(_custodianWallet);
        return true;
    }

    /// @notice Allows the owner of the contract to set the issuer
    /// @param _issuer address
    /// @return bool
    function setIssuer(address _issuer) external override onlyOwner returns (bool) {
        require(_issuer != address(0), "invalid issuer address");
        issuer = _issuer;

        emit IssuerSet(_issuer);
        return true;
    }

    /// @notice set nft address
    /// @param _nft address
    /// @return bool
    function setNFT(address _nft) external onlyOwner returns (bool) {
        require(_nft != address(0), "invalid nft address");
        nft = RequestNFT(_nft);

        emit NFTSet(_nft);
        return true;
    }

    function getAllMintRequests() public view returns (Request[] memory) {
        return mintRequests;
    }

    function getAllBurnRequests() public view returns (Request[] memory) {
        return burnRequests;
    }

    /// @notice Allows a user to initiate a mint request
    /// @param amount uint256
    /// @return bool
    function addMintRequest(
        uint256 amount,
        address user
    ) external override whenNotPaused returns (uint256, bytes32) {
        uint feeAmount = (amount*feeRate)/10000;
        uint finalAmount = amount + feeAmount;

        //transfer usdc to custodian wallet
        SafeERC20.safeTransferFrom(
            IERC20(usdc),
            msg.sender,
            custodianWallet,
            amount
        );
        //transfer fee to the owner
        SafeERC20.safeTransferFrom(
            IERC20(usdc),
            msg.sender,
            owner(),
            feeAmount
        );

        uint256 nonce = mintRequests.length;
        uint256 timestamp = getTimestamp();

        Request memory request = Request({
            requester: user,
            amount: amount,
            depositAddress: custodianWallet,
            nonce: nonce,
            timestamp: timestamp,
            status: RequestStatus.PENDING
        });

        bytes32 requestHash = calcRequestHash(request);
        mintRequestNonce[requestHash] = nonce;
        mintRequests.push(request);

        //mint nft
        nft.addMintRequestNFT(token.name(), user, amount);

        emit MintRequestAdd(
            nonce,
            user,
            amount,
            custodianWallet,
            timestamp,
            requestHash
        );
        return (nonce, requestHash);
    }

    

    /// @notice Allows a issuer to confirm a mint request
    /// @param requestHash bytes32
    /// @return bool
    function confirmMintRequest(
        bytes32 requestHash,
        uint _tokenAmount
    ) external override onlyIssuer returns (bool) {
        uint256 nonce;
        Request memory request;

        (nonce, request) = getPendingMintRequest(requestHash);
        mintRequests[nonce].status = RequestStatus.APPROVED;
        
        token.mint(request.requester, _tokenAmount);
        

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

    

    /// @notice Allows a merchant to initiate a burn request
    /// @param amount uint256
    /// @return bool
    function burn(
        uint256 amount,
        address user
    ) external override whenNotPaused returns (uint256, bytes32) {
        uint256 nonce = burnRequests.length;
        uint256 timestamp = getTimestamp();

        Request memory request = Request({
            requester: user,
            amount: amount,
            depositAddress: user,
            nonce: nonce,
            timestamp: timestamp,
            status: RequestStatus.PENDING
        });

        bytes32 requestHash = calcRequestHash(request);
        burnRequestNonce[requestHash] = nonce;
        burnRequests.push(request);

        token.burn(msg.sender, amount);

        //mint nft
        nft.addBurnRequestNFT(token.name(), user, amount);

        emit Burned(
            nonce,
            user,
            amount,
            custodianWallet,
            timestamp,
            requestHash
        );
        return (nonce, requestHash);
    }

    /// @notice Allows a issuer to confirm a burn request
    /// @param requestHash bytes32
    /// @return bool
    function confirmBurnRequest(
        bytes32 requestHash
    ) external override onlyIssuer returns (bool) {
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

    function getBurnRequestsLength()
        external
        view
        override
        returns (uint256 length)
    {
        return burnRequests.length;
    }

    /// @notice Gets a burn request by nonce
    /// @dev Returns the fields present in the request struct and also the request hash
    /// @param nonce uint256
    function getBurnRequest(
        uint256 nonce
    )
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
    function getMintRequest(
        uint256 nonce
    )
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

    function getPendingMintRequest(
        bytes32 requestHash
    ) internal view returns (uint256 nonce, Request memory request) {
        require(requestHash != 0, "request hash is 0");
        nonce = mintRequestNonce[requestHash];
        request = mintRequests[nonce];
        validatePendingRequest(request, requestHash);
    }

    function getPendingBurnRequest(
        bytes32 requestHash
    ) internal view returns (uint256 nonce, Request memory request) {
        require(requestHash != 0, "request hash is 0");
        nonce = burnRequestNonce[requestHash];
        request = burnRequests[nonce];
        validatePendingRequest(request, requestHash);
    }

    function getMintRequestsLength()
        external
        view
        override
        returns (uint256 length)
    {
        return mintRequests.length;
    }

    function validatePendingRequest(
        Request memory request,
        bytes32 requestHash
    ) internal pure {
        require(
            request.status == RequestStatus.PENDING,
            "request is not pending"
        );
        require(
            requestHash == calcRequestHash(request),
            "given request hash does not match a pending request"
        );
    }

    function calcRequestHash(
        Request memory request
    ) internal pure returns (bytes32) {
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

    function compareStrings(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return (keccak256(abi.encodePacked(a)) ==
            keccak256(abi.encodePacked(b)));
    }

    function isEmptyString(string memory a) internal pure returns (bool) {
        return (compareStrings(a, ""));
    }

    function getStatusString(
        RequestStatus status
    ) internal pure returns (string memory) {
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
