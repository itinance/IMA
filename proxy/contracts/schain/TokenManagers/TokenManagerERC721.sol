// SPDX-License-Identifier: AGPL-3.0-only

/**
 *   TokenManager.sol - SKALE Interchain Messaging Agent
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
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../../Messages.sol";
import "../TokenFactories/TokenFactoryERC721.sol";
import "../TokenManager.sol";


/**
 * @title Token Manager
 * @dev Runs on SKALE Chains, accepts messages from mainnet, and instructs
 * TokenFactory to create clones. TokenManager mints tokens via
 * LockAndDataForSchain*. When a user exits a SKALE chain, TokenFactory
 * burns tokens.
 */
contract TokenManagerERC721 is TokenManager {

    TokenFactoryERC721 private _tokenFactory;

    mapping(bytes32 => address) public tokenManagerERC721Addresses;
    // address of ERC721 on Mainnet => ERC721 on Schain
    mapping(bytes32 => mapping(address => ERC721OnChain)) public schainToERC721OnSchain;

    event ERC721TokenAdded(string chainID, address indexed erc721OnMainnet, address indexed erc721OnSchain);

    event ERC721TokenCreated(string chainID, address indexed erc721OnMainnet, address indexed erc721OnSchain);

    modifier rightTransaction(string memory schainID) {
        bytes32 schainHash = keccak256(abi.encodePacked(schainID));
        require(
            schainHash != keccak256(abi.encodePacked("Mainnet")),
            "This function is not for transferring to Mainnet"
        );
        require(tokenManagerERC721Addresses[schainHash] != address(0), "Incorrect Token Manager address");
        _;
    }

    constructor(
        string memory newChainID,
        MessageProxyForSchain newMessageProxy,
        TokenManagerLinker newIMALinker,
        address newDepositBox
    )
        public
        TokenManager(newChainID, newMessageProxy, newIMALinker, newDepositBox)
        // solhint-disable-next-line no-empty-blocks
    { }

    function setTokenFactory(TokenFactoryERC721 newTokenFactory) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized caller");
        _tokenFactory = newTokenFactory;
    }

    /**
     * @dev Adds a depositBox address to
     * TokenManagerEth.
     *
     * Requirements:
     *
     * - `msg.sender` must be schain owner or contract owner
     * = or imaLinker contract.
     * - depositBox must not already be added.
     * - depositBox address must be non-zero.
     */
    function addDepositBox(address newdepositBoxAddress) external override {
        require(
            msg.sender == address(tokenManagerLinker) ||
            _isSchainOwner(msg.sender) ||
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized caller"
        );
        require(depositBox == address(0), "depositBox is already set");
        require(newdepositBoxAddress != address(0), "Incorrect DepositBoxEth address");
        depositBox = newdepositBoxAddress;
    }

    /**
     * @dev Allows Owner to remove a depositBox on SKALE chain
     * from TokenManagerEth.
     *
     * Requirements:
     *
     * - `msg.sender` must be schain owner or contract owner
     * = or imaLinker contract.
     * - depositBox must already be set.
     */
    function removeDepositBox() external override {
        require(
            msg.sender == address(tokenManagerLinker) ||
            _isSchainOwner(msg.sender) ||
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized caller"
        );
        require(depositBox != address(0), "depositBox is not set");
        delete depositBox;
    }

    /**
     * @dev Adds a TokenManagerEth address to
     * depositBox.
     *
     * Requirements:
     *
     * - `msg.sender` must be schain owner or contract owner
     * = or imaLinker contract.
     * - SKALE chain must not already be added.
     * - TokenManager address must be non-zero.
     */
    function addTokenManager(string calldata schainID, address newTokenManagerERC721Address) external override {
        require(
            msg.sender == address(tokenManagerLinker) ||
            _isSchainOwner(msg.sender) ||
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized caller"
        );
        bytes32 schainHash = keccak256(abi.encodePacked(schainID));
        require(tokenManagerERC721Addresses[schainHash] == address(0), "SKALE chain is already set");
        require(newTokenManagerERC721Address != address(0), "Incorrect Token Manager address");
        tokenManagerERC721Addresses[schainHash] = newTokenManagerERC721Address;
    }

    /**
     * @dev Allows Owner to remove a TokenManagerEth on SKALE chain
     * from depositBox.
     *
     * Requirements:
     *
     * - `msg.sender` must be schain owner or contract owner
     * - SKALE chain must already be set.
     */
    function removeTokenManager(string calldata schainID) external override {
        require(
            msg.sender == address(tokenManagerLinker) ||
            _isSchainOwner(msg.sender) ||
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not authorized caller"
        );
        bytes32 schainHash = keccak256(abi.encodePacked(schainID));
        require(tokenManagerERC721Addresses[schainHash] != address(0), "SKALE chain is not set");
        delete tokenManagerERC721Addresses[schainHash];
    }

    function exitToMainERC721(
        address contractOnMainnet,
        address to,
        uint256 tokenId
    )
        external
    {
        IERC721 contractOnSchain = schainToERC721OnSchain[keccak256(abi.encodePacked("Mainnet"))][contractOnMainnet];
        require(contractOnSchain.getApproved(tokenId) == address(this), "Not allowed ERC721 Token");
        contractOnSchain.transferFrom(msg.sender, address(this), tokenId);
        require(contractOnSchain.ownerOf(tokenId) == address(this), "Did not transfer ERC721 token");
        // require(amountOfEth >= TX_FEE, "Not enough funds to exit");
        // uint amountOfEthToSend = amountOfEth >= TX_FEE ?
        //     amountOfEth :
        //     ILockAndDataTM(getLockAndDataAddress()).reduceCommunityPool(TX_FEE) ? TX_FEE : 0;
        // require(amountOfEthToSend != 0, "Community pool is empty");
        bytes memory data = _receiveERC721(
            "Mainnet",
            contractOnMainnet,
            to,
            tokenId
        );
        messageProxy.postOutgoingMessage(
            "Mainnet",
            depositBox,
            data
        );
    }

    function transferToSchainERC721(
        string calldata schainID,
        address contractOnMainnet,
        address to,
        uint256 tokenId
    ) 
        external
    {
        IERC721 contractOnSchain = schainToERC721OnSchain[keccak256(abi.encodePacked(schainID))][contractOnMainnet];
        require(contractOnSchain.getApproved(tokenId) == address(this), "Not allowed ERC721 Token");
        contractOnSchain.transferFrom(msg.sender, address(this), tokenId);
        require(contractOnSchain.ownerOf(tokenId) == address(this), "Did not transfer ERC721 token");
        bytes memory data = _receiveERC721(
            schainID,
            contractOnMainnet,
            to,
            tokenId
        );
        messageProxy.postOutgoingMessage(
            schainID,
            tokenManagerERC721Addresses[keccak256(abi.encodePacked(schainID))],
            data
        );
    }

    /**
     * @dev Allows MessageProxy to post operational message from mainnet
     * or SKALE chains.
     * 
     * Emits an {Error} event upon failure.
     *
     * Requirements:
     * 
     * - MessageProxy must be the sender.
     * - `fromSchainID` must exist in TokenManager addresses.
     */
    function postMessage(
        string calldata fromSchainID,
        address sender,
        bytes calldata data
    )
        external
        override
        returns (bool)
    {
        require(msg.sender == address(messageProxy), "Not a sender");
        bytes32 schainHash = keccak256(abi.encodePacked(fromSchainID));
        require(
            schainHash != schainId && 
            (
                schainHash == keccak256(abi.encodePacked("Mainnet")) ?
                sender == depositBox :
                sender == tokenManagerERC721Addresses[schainHash]
            ),
            "Receiver chain is incorrect"
        );
        Messages.MessageType operation = Messages.getMessageType(data);
        if (
            operation == Messages.MessageType.TRANSFER_ERC721_AND_TOKEN_INFO ||
            operation == Messages.MessageType.TRANSFER_ERC721
        ) {
            require(_sendERC721(fromSchainID, data), "Failed to send ERC721");
        } else {
            revert("MessageType is unknown");
        }
        return true;
    }

    /**
     * @dev Allows Schain owner to add an ERC721 token to LockAndDataForSchainERC721.
     */
    function addERC721TokenByOwner(
        string calldata schainName,
        address erc721OnMainnet,
        ERC721OnChain erc721OnSchain
    )
        external
    {
        require(_isSchainOwner(msg.sender), "Sender is not an Schain owner");
        require(address(erc721OnSchain).isContract(), "Given address is not a contract");
        schainToERC721OnSchain[keccak256(abi.encodePacked(schainName))][erc721OnMainnet] = erc721OnSchain;
        emit ERC721TokenAdded(schainName, erc721OnMainnet, address(erc721OnSchain));
    }

    /**
     * @dev Checks whether TokenManagerERC721 is connected to a {schainID} SKALE chain TokenManagerERC721.
     */
    function hasTokenManager(string calldata schainID) external view override returns (bool) {
        return tokenManagerERC721Addresses[keccak256(abi.encodePacked(schainID))] != address(0);
    }

    /**
     * @dev Checks whether TokenManagerERC721 is connected to a mainnet depositBox.
     */
    function hasDepositBox() external view override returns (bool) {
        return depositBox != address(0);
    }

    /**
     * @dev Allows TokenManager to receive ERC721 tokens.
     * 
     * Requirements:
     * 
     * - ERC721 token contract must exist in LockAndDataForSchainERC721.
     * - ERC721 token must be received by LockAndDataForSchainERC721.
     */
    function _receiveERC721(
        string memory schainID,
        address contractOnMainnet,
        address receiver,
        uint256 tokenId
    ) 
        private
        returns (bytes memory data)
    {
        ERC721Burnable contractOnSchain = 
            schainToERC721OnSchain[keccak256(abi.encodePacked(schainID))][contractOnMainnet];
        require(address(contractOnSchain) != address(0), "ERC721 contract does not exist on SKALE chain");
        require(contractOnSchain.ownerOf(tokenId) == address(this), "Token not transferred");
        contractOnSchain.burn(tokenId);
        data = Messages.encodeTransferErc721Message(contractOnMainnet, receiver, tokenId);
    }

    /**
     * @dev Allows TokenManager to send ERC721 tokens.
     *  
     * Emits a {ERC721TokenCreated} event if to address = 0.
     */
    function _sendERC721(string calldata schainID, bytes calldata data) private returns (bool) {
        Messages.MessageType messageType = Messages.getMessageType(data);
        address receiver;
        address token;
        uint256 tokenId;
        if (messageType == Messages.MessageType.TRANSFER_ERC721){
            Messages.TransferErc721Message memory message = Messages.decodeTransferErc721Message(data);
            receiver = message.receiver;
            token = message.token;
            tokenId = message.tokenId;
        } else {
            Messages.TransferErc721AndTokenInfoMessage memory message =
                Messages.decodeTransferErc721AndTokenInfoMessage(data);
            receiver = message.baseErc721transfer.receiver;
            token = message.baseErc721transfer.token;
            tokenId = message.baseErc721transfer.tokenId;
            ERC721OnChain contractOnSchainTmp = schainToERC721OnSchain[keccak256(abi.encodePacked(schainID))][token];
            if (address(contractOnSchainTmp) == address(0)) {
                contractOnSchainTmp = getTokenFactoryERC721()
                    .createERC721(message.tokenInfo.name, message.tokenInfo.symbol);
                require(address(contractOnSchainTmp).isContract(), "Given address is not a contract");
                require(automaticDeploy, "Automatic deploy is disabled");
                schainToERC721OnSchain[keccak256(abi.encodePacked(schainID))][token] = contractOnSchainTmp;
                emit ERC721TokenCreated(schainID, token, address(contractOnSchainTmp));
            }
        }
        ERC721OnChain contractOnSchain = schainToERC721OnSchain[keccak256(abi.encodePacked(schainID))][token];
        require(contractOnSchain.mint(receiver, tokenId), "Could not mint ERC721 Token");
        return true;
    }

    function getTokenFactoryERC721() public view returns (TokenFactoryERC721) {
        if (address(_tokenFactory) == address(0)) {
            return TokenFactoryERC721(
                getSkaleFeatures().getConfigVariableAddress(
                    "skaleConfig.contractSettings.IMA.TokenFactoryERC721"
                )
            );
        }
        return _tokenFactory;
    }
}