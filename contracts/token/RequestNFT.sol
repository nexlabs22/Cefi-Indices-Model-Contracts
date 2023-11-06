// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "base64-sol/base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@thirdweb-dev/contracts/eip/interface/IERC721Supply.sol";

contract RequestNFT is ERC721URIStorage, Ownable, IERC721Supply {

    event MinterSet(address indexed minter);
    event AddMintRequestNFT(address indexed _userAddress, uint256 _amount, uint256 _time);
    event AddBurnRequestNFT(address indexed _userAddress, uint256 _amount, uint256 _time);

    uint256 private tokenIdCounter;
    address public minter;

    string public exampleURL = "https://dapp-spot-index.vercel.app/api/getNFT?type=mint&amount=10000000000000000&time=353535";
    // string public exampleURL = "https://product-nextjs-sandy.vercel.app/api/getNFT?type=mint&amount=10000000000000000&time=353535";
    string public baseUrl = "https://dapp-spot-index.vercel.app/api/getNFT?type=";
    // string public baseUrl = "https://product-nextjs-sandy.vercel.app/api/getNFT?type=";

    constructor(
        string memory _name,
        string memory _symbol,
        address _minter
    ) ERC721(_name, _symbol) {
        tokenIdCounter = 1;
        minter = _minter;
    }


    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0));
        minter = _minter;
        emit MinterSet(_minter);
    }


    function totalSupply() public view override returns (uint256) {
        return tokenIdCounter;
    }

    
    function addMintRequestNFT(string memory _indexName, address _userAddress, uint256 _amount) public {

        uint256 tokenId = tokenIdCounter;
        _mint(_userAddress, tokenId);

        string memory tokenURI = buildMetadata(
            _indexName,
            _amount,
            block.timestamp,
            "mint"
        );

        _setTokenURI(tokenId, tokenURI);

        tokenIdCounter++;

        emit AddMintRequestNFT(_userAddress, _amount, block.timestamp);
    }


    function addBurnRequestNFT(string memory _indexName, address _userAddress, uint256 _amount) public {

        uint256 tokenId = tokenIdCounter;
        _mint(_userAddress, tokenId);

        
        string memory tokenURI = buildMetadata(
            _indexName,
            _amount,
            block.timestamp,
            "burn"
        );

        _setTokenURI(tokenId, tokenURI);

        tokenIdCounter++;
        emit AddBurnRequestNFT(_userAddress, _amount, block.timestamp);
    }


    function buildMetadata(
        string memory _indexName,
        uint256 _amount,
        uint256 _timestamp,
        string memory _requestType
    )
        private
        view
        returns (string memory)
    {
        string memory uri = generateURI(_indexName, _requestType, _amount, _timestamp);
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"Dynamic NFT", "description":"Dynamic NFT Test", ',
                                '"image": ',
                                '"',
                                uri,
                                '"',
                                "}"
                            )
                        )
                    )
                )
            );
    }


    function generateURI(string memory _indexName, string memory _requestType, uint amount, uint _timestamp) public view returns(string memory) {
        string memory currentTime = formatTimestamp(_timestamp);

        return string(abi.encodePacked(
            baseUrl, 
            _requestType,
            "&amount=",
            uintToStr(amount),
            "&time=",
            currentTime,
            "&indexName=",
            _indexName
             ));
    }

    function uintToStr(uint256 _value) internal pure returns (string memory) {
        if (_value == 0) {
            return "0";
        }
        uint256 tempValue = _value;
        uint256 digits;
        while (tempValue != 0) {
            digits++;
            tempValue /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (_value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + (_value % 10)));
            _value /= 10;
        }
        return string(buffer);
    }


    function formatTimestamp(
        uint256 _timestamp
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(toString(_timestamp), ""));
    }


    function toString(uint256 _value) internal pure returns (string memory) {
        if (_value == 0) {
            return "0";
        }
        uint256 tempValue = _value;
        uint256 digits;
        while (tempValue != 0) {
            digits++;
            tempValue /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (_value != 0) {
            digits--;
            buffer[digits] = bytes1(uint8(48 + (_value % 10)));
            _value /= 10;
        }
        return string(buffer);
    }
}