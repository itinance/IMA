pragma solidity ^0.5.0;

import "./Permissions.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721Full.sol";

interface LockAndDataERC721 {
    function ERC721Tokens(uint index) external returns (address);
    function ERC721Mapper(address contractERC721) external returns (uint);
    function addERC721Token(address contractERC721) external returns (uint);
    function sendERC721(address contractHere, address to, uint token) external returns (bool);
}

contract ERC721ModuleForMainnet is Permissions {

    constructor(address payable newLockAndDataAddress) Permissions(newLockAndDataAddress) public {
        
    }

    function receiveERC721(address contractHere, address to, uint tokenId, bool isRAW) public returns (bytes memory data) {
        address lockAndDataERC721 = ContractManager(lockAndDataAddress).permitted(keccak256(abi.encodePacked("LockAndDataERC721")));
        if (!isRAW) {
            uint contractPosition = LockAndDataERC721(lockAndDataERC721).ERC721Mapper(contractHere);
            if (contractPosition == 0) {
                contractPosition = LockAndDataERC721(lockAndDataERC721).addERC721Token(contractHere);
            }
            return encodeData(contractHere, contractPosition, to, tokenId);
        } else {
            return encodeRawData(to, tokenId);
        }
    }

    function encodeData(address contractHere, uint contractPosition, address to, uint tokenId) internal view returns (bytes memory data) {
        string memory name = IERC721Full(contractHere).name();
        string memory symbol = IERC721Full(contractHere).symbol();
        data = abi.encodePacked(
            bytes1(uint8(5)),
            bytes32(contractPosition),
            bytes32(bytes20(to)),
            bytes32(tokenId),
            bytes(name).length,
            name,
            bytes(symbol).length,
            symbol
        );
    }

    function encodeRawData(address to, uint tokenId) internal pure returns (bytes memory data) {
        data = abi.encodePacked(
            bytes1(uint8(21)),
            bytes32(bytes20(to)),
            bytes32(tokenId)
        );
    }

    function sendERC721(address to, bytes memory data) public returns (bool) {
        address lockAndDataERC721 = ContractManager(lockAndDataAddress).permitted(keccak256(abi.encodePacked("LockAndDataERC721")));
        uint contractPosition;
        address contractAddress;
        address receiver;
        uint tokenId;
        if (to == address(0)) {
            (contractPosition, receiver, tokenId) = fallbackDataParser(data);
            contractAddress = LockAndDataERC721(lockAndDataERC721).ERC721Tokens(contractPosition);
        } else {
            (receiver, tokenId) = fallbackRawDataParser(data);
            contractAddress = to;
        }
        return LockAndDataERC721(lockAndDataERC721).sendERC721(contractAddress, receiver, tokenId);
    }

    function fallbackDataParser(bytes memory data)
        internal
        pure
        returns (uint, address payable, uint)
    {
        bytes32 contractIndex;
        bytes32 to;
        bytes32 token;
        assembly {
            contractIndex := mload(add(data, 33))
            to := mload(add(data, 65))
            token := mload(add(data, 97))
        }
        return (
            uint(contractIndex), address(bytes20(to)), uint(token)
        );
    }

    function fallbackRawDataParser(bytes memory data)
        internal
        pure
        returns (address payable, uint)
    {
        bytes32 to;
        bytes32 token;
        assembly {
            to := mload(add(data, 33))
            token := mload(add(data, 65))
        }
        return (address(bytes20(to)), uint(token));
    }

}