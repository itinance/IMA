// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   SkaleFeatures.sol - SKALE Interchain Messaging Agent
 *   Copyright (C) 2019-Present SKALE Labs
 *   @author Sergiy Lavrynenko
 *
 *   SKALE IMA is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU Affero General Public License as published
 *   by the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   SKALE IMA is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU Affero General Public License for more details.
 *
 *   You should have received a copy of the GNU Affero General Public License
 *   along with SKALE IMA.  If not, see <https://www.gnu.org/licenses/>.
 */

pragma solidity 0.6.12;


contract SkaleFeatures {

    uint256 public constant FREE_MEM_PTR = 0x40;
    uint256 public constant FN_NUM_LOG_TEXT_MESSAGE = 0x12;
    uint256 public constant FN_NUM_GET_CONFIG_VARIABLE_UINT256 = 0x13;
    uint256 public constant FN_NUM_GET_CONFIG_VARIABLE_ADDRESS = 0x14;
    uint256 public constant FN_NUM_GET_CONFIG_VARIABLE_STRING = 0x15;
    uint256 public constant FN_NUM_RESERVED = 0x16;
    uint256 public constant FN_NUM_GET_CONFIG_PERMISSION_FLAG = 0x17;

    function getConfigVariableUint256(
        string memory strConfigVariableName
    )
        external
        view
        virtual
        returns ( uint256 rv )
    {
        uint256 fmp = FREE_MEM_PTR;
        uint256 blocks = (bytes(strConfigVariableName).length + 31) / 32 + 1;
        bool success;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(fmp)
            for { let i := 0 } lt( i, blocks ) { i := add(1, i) } {
                let where := add(ptr, mul(32, i))
                let what := mload(add(strConfigVariableName, mul(32, i)))
                mstore(where, what)
            }
            success := staticcall(not(0), FN_NUM_GET_CONFIG_VARIABLE_UINT256, ptr, mul( blocks, 32 ), ptr, 32)
            rv := mload(ptr)
        }
        require(success, "Get config uint256 failed");
    }

    function getConfigVariableAddress(
        string memory strConfigVariableName
    )
        external
        view
        virtual
        returns ( address rv )
    {
        uint256 fmp = FREE_MEM_PTR;
        uint256 blocks = (bytes(strConfigVariableName).length + 31) / 32 + 1;
        bool success;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(fmp)
            for { let i := 0 } lt( i, blocks ) { i := add(1, i) } {
                let where := add(ptr, mul(32, i))
                let what := mload(add(strConfigVariableName, mul(32, i)))
                mstore(where, what)
            }
            success := staticcall(not(0), FN_NUM_GET_CONFIG_VARIABLE_ADDRESS, ptr, mul( blocks, 32 ), ptr, 32)
            rv := mload(ptr)
        }
        require(success, "Get config address failed");
    }

    function logTextMessage( uint256 messageType, string memory strTextMessage ) public view returns ( uint256 rv ) {
        uint256 fmp = FREE_MEM_PTR;
        uint256 fnc = FN_NUM_LOG_TEXT_MESSAGE;
        address who = msg.sender;
        uint256 blocks = (bytes(strTextMessage).length + 31) / 32 + 1;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let p := mload(fmp)
            let ptr := p
            // who
            mstore(ptr, who)
            ptr := add(ptr, 32)
            // type
            mstore(ptr, messageType )
            ptr := add(ptr, 32)
            // message
            for { let i := 0 } lt( i, blocks ) { i := add(1, i) } {
                let where := add(ptr, mul(32, i))
                let what := mload(add( strTextMessage, mul(32, i)))
                mstore(where, what)
            }
            rv := staticcall(not(0), fnc, p, add( 64, mul(blocks, 32) ), p, 32)
        }
    }

    function logMessage( string memory strMessage ) public view returns  (uint256 rv) {
        rv = logTextMessage(0, strMessage);
    }

    function logDebug  ( string memory strMessage ) public view returns  (uint256 rv) {
        rv = logTextMessage(1, strMessage);
    }

    function logTrace  ( string memory strMessage ) public view returns  (uint256 rv) {
        rv = logTextMessage(2, strMessage);
    }

    function logWarning( string memory strMessage ) public view returns  (uint256 rv) {
        rv = logTextMessage(3, strMessage);
    }

    function logError  ( string memory strMessage ) public view returns  (uint256 rv) {
        rv = logTextMessage(4, strMessage);
    }

    function logFatal  ( string memory strMessage ) public view returns  (uint256 rv) {
        rv = logTextMessage(5, strMessage);
    }

    function getConfigVariableString( string memory strConfigVariableName ) public view returns ( string memory rv ) {
        uint256 fmp = FREE_MEM_PTR;
        uint256 blocks = (bytes(strConfigVariableName).length + 31) / 32 + 1;
        bool success;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let ptr := mload(fmp)
            for { let i := 0 } lt( i, blocks ) { i := add(1, i) } {
                let where := add(ptr, mul(32, i))
                let what := mload(add(strConfigVariableName, mul(32, i)))
                mstore(where, what)
            }
            success := staticcall(
                not(0),
                FN_NUM_GET_CONFIG_VARIABLE_STRING,
                ptr,
                mul( blocks, 32 ),
                rv,
                mul( 1024, 1024 )
            )
        }
        require(success, "Get config string failed");
    }

    function getConfigPermissionFlag(address a, string memory strConfigVariableName) public view returns (uint256 rv) {
        uint256 fmp = FREE_MEM_PTR;
        uint256 fnc = FN_NUM_GET_CONFIG_PERMISSION_FLAG;
        uint256 blocks = (bytes(strConfigVariableName).length + 31) / 32 + 1;
        bool success;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            let p := mload(fmp)
            mstore(p, a)
            let ptr := add(p, 32)
            for { let i := 0 } lt( i, blocks ) { i := add(1, i) } {
                let where := add(ptr, mul(32, i))
                let what := mload(add(strConfigVariableName, mul(32, i)))
                mstore(where, what)
            }
            success := staticcall(not(0), fnc, p, add(64, mul(blocks, 32) ), p, 32)
            rv := mload(ptr)
        }
        require(success, "Get config permission failed");
    }

    function addressToAsciiStringDec(address x) public pure returns (string memory _uintAsString) {
        uint _i = uint256(x);
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }
    function addressToAsciiString(address x) public pure returns (string memory) {
        bytes memory data = abi.encodePacked(x);
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; i++) {
            str[2+i*2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3+i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }
}

