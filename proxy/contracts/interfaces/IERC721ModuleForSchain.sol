// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   IERC721ModuleForSchain.sol - SKALE Interchain Messaging Agent
 *   Copyright (C) 2019-Present SKALE Labs
 *   @author Artem Payvin
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


interface IERC721ModuleForSchain {
    function receiveERC721(
        string calldata schainID,
        address contractOnMainnet,
        address to,
        uint256 tokenId) external returns (bytes memory);
    function sendERC721(string calldata schainID, bytes calldata data) external returns (bool);
    function getReceiver(bytes calldata data) external pure returns (address);
}