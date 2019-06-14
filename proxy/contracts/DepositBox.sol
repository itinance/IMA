pragma solidity ^0.5.0;

import "./Ownable.sol";
import "./Permissions.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/token/ERC721/IERC721Full.sol";

interface Proxy {
    function postOutgoingMessage(
        string calldata dstChainID,
        address dstContract,
        uint amount,
        address to,
        bytes calldata data
    )
        external;
}

interface LockAndData {
    function setContract(string calldata contractName, address newContract) external;
    function tokenManagerAddresses(bytes32 schainHash) external returns (address);
    function sendEth(address to, uint amount) external returns (bool);
    function approveTransfer(address to, uint amount) external;
    function addSchain(string calldata schainID, address tokenManagerAddress) external;
    function receiveEth(address from) external payable;
}

interface ERC20Module {
    function receiveERC20(address contractHere, address to, uint amount, bool isRaw) external returns (bytes memory);
    function sendERC20(address to, bytes calldata data) external returns (bool);
}

interface ERC721Module {
    function receiveERC721(address contractHere, address to, uint tokenId, bool isRaw) external returns (bytes memory);
    function sendERC721(address to, bytes calldata data) external returns (bool);
}

// This contract runs on the main net and accepts deposits

contract DepositBox is Permissions {

    //address public skaleManagerAddress;

    enum TransactionOperation {
        transferETH,
        transferERC20,
        transferERC721,
        rawTransferERC20,
        rawTransferERC721
    }

    address public proxyAddress;

    uint public constant GAS_AMOUNT_POST_MESSAGE = 55000; // 0;
    uint public constant AVERAGE_TX_PRICE = 1000000000;

    //mapping(address => mapping(address => uint)) public allowed;

    event MoneyReceivedMessage(
        address sender,
        string fromSchainID,
        address to,
        uint amount,
        bytes data
    );

    event Error(
        address sender,
        string fromSchainID,
        address to,
        uint amount,
        bytes data,
        string message
    );

    modifier rightTransaction(string memory schainID) {
        bytes32 schainHash = keccak256(abi.encodePacked(schainID));
        address tokenManagerAddress = LockAndData(lockAndDataAddress).tokenManagerAddresses(schainHash);
        require(schainHash != keccak256(abi.encodePacked("Mainnet")), "Schain name is incorrect");
        require(tokenManagerAddress != address(0), "Unconnected chain");
        require(msg.value >= GAS_AMOUNT_POST_MESSAGE * AVERAGE_TX_PRICE, "Not enough money");
        _;
    }

    /// Create a new deposit box
    constructor(address newProxyAddress, address payable newLockAndDataAddress) Permissions(newLockAndDataAddress) public {
        proxyAddress = newProxyAddress;
        lockAndDataAddress = newLockAndDataAddress;
    }

    function() external payable {
        revert("Not allowed");
    }

    function deposit(string memory schainID, address to) public payable {
        bytes memory empty;
        deposit(schainID, to, empty);
    }

    function deposit(string memory schainID, address to, bytes memory data)
        public
        payable
        rightTransaction(schainID)
    {
        bytes32 schainHash = keccak256(abi.encodePacked(schainID));
        address tokenManagerAddress = LockAndData(lockAndDataAddress).tokenManagerAddresses(schainHash);
        bytes memory newData;
        newData = abi.encodePacked(bytes1(uint8(1)), data);
        Proxy(proxyAddress).postOutgoingMessage(
            schainID,
            tokenManagerAddress,
            msg.value,
            to,
            newData
        );
        LockAndData(lockAndDataAddress).receiveEth.value(msg.value)(msg.sender);
    }

    function depositERC20(
        string memory schainID,
        address contractHere,
        address to,
        uint amount
    )
        public
        payable
        rightTransaction(schainID)
    {
        bytes32 schainHash = keccak256(abi.encodePacked(schainID));
        address tokenManagerAddress = LockAndData(lockAndDataAddress).tokenManagerAddresses(schainHash);
        address lockAndDataERC20 = ContractManager(lockAndDataAddress).permitted(keccak256(abi.encodePacked("LockAndDataERC20")));
        address erc20Module = ContractManager(lockAndDataAddress).permitted(keccak256(abi.encodePacked("ERC20Module")));
        require(
            IERC20(contractHere).allowance(
                msg.sender,
                address(this)
            ) >= amount,
            "Not allowed ERC20 Token"
        );
        require(
            IERC20(contractHere).transferFrom(
                msg.sender,
                lockAndDataERC20,
                amount
            ),
            "Could not transfer ERC20 Token"
        );
        bytes memory data = ERC20Module(erc20Module).receiveERC20(contractHere, to, amount, false);
        Proxy(proxyAddress).postOutgoingMessage(
            schainID,
            tokenManagerAddress,
            msg.value,
            address(0),
            data
        );
    }

    function rawDepositERC20(
        string memory schainID,
        address contractHere,
        address contractThere,
        address to,
        uint amount
    )
        public
        payable
        rightTransaction(schainID)
    {
        bytes32 schainHash = keccak256(abi.encodePacked(schainID));
        address tokenManagerAddress = LockAndData(lockAndDataAddress).tokenManagerAddresses(schainHash);
        address lockAndDataERC20 = ContractManager(lockAndDataAddress).permitted(keccak256(abi.encodePacked("LockAndDataERC20")));
        address erc20Module = ContractManager(lockAndDataAddress).permitted(keccak256(abi.encodePacked("ERC20Module")));
        require(
            IERC20(contractHere).allowance(
                msg.sender,
                address(this)
            ) >= amount,
            "Not allowed ERC20 Token"
        );
        require(
            IERC20(contractHere).transferFrom(
                msg.sender,
                lockAndDataERC20,
                amount
            ),
            "Could not transfer ERC20 Token"
        );
        bytes memory data = ERC20Module(erc20Module).receiveERC20(contractHere, to, amount, true);
        Proxy(proxyAddress).postOutgoingMessage(
            schainID,
            tokenManagerAddress,
            msg.value,
            contractThere,
            data
        );
    }

    function depositERC721(string memory schainID, address contractHere, address to, uint tokenId) public payable rightTransaction(schainID) {
        bytes32 schainHash = keccak256(abi.encodePacked(schainID));
        address lockAndDataERC721 = ContractManager(lockAndDataAddress).permitted(keccak256(abi.encodePacked("LockAndDataERC721")));
        address erc721Module = ContractManager(lockAndDataAddress).permitted(keccak256(abi.encodePacked("ERC721Module")));
        require(IERC721Full(contractHere).ownerOf(tokenId) == address(this), "Not allowed ERC721 Token");
        IERC721Full(contractHere).transferFrom(msg.sender, lockAndDataERC721, tokenId);
        require(IERC721Full(contractHere).ownerOf(tokenId) == lockAndDataERC721, "Did not transfer ERC721 token");
        bytes memory data = ERC721Module(erc721Module).receiveERC721(contractHere, to, tokenId, true);
        Proxy(proxyAddress).postOutgoingMessage(
            schainID,
            LockAndData(lockAndDataAddress).tokenManagerAddresses(schainHash),
            msg.value,
            address(0),
            data
        );
    }

    function postMessage(
        address sender,
        string memory fromSchainID,
        address payable to,
        uint amount,
        bytes memory data
    )
        public
    {
        require(msg.sender == proxyAddress, "Incorrect sender");
        bytes32 schainHash = keccak256(abi.encodePacked(fromSchainID));
        if (
            schainHash == keccak256(abi.encodePacked("Mainnet")) ||
            sender != LockAndData(lockAndDataAddress).tokenManagerAddresses(schainHash)
        ) {
            emit Error(
                sender,
                fromSchainID,
                to,
                amount,
                data,
                "Receiver chain is incorrect"
            );
        }
        if (!(amount <= address(lockAndDataAddress).balance) && !(amount >= GAS_AMOUNT_POST_MESSAGE * AVERAGE_TX_PRICE)) {
            emit Error(
                sender,
                fromSchainID,
                to,
                amount,
                data,
                "Not enough money to finish this transaction"
            );
            return;
        }

        if (data.length == 0) {
            emit Error(sender, fromSchainID, to, amount, data, "Invalid data");
            return;
        }

        TransactionOperation operation = fallbackOperationTypeConvert(data);
        if (operation == TransactionOperation.transferETH) {
            if (!LockAndData(lockAndDataAddress).sendEth(owner, GAS_AMOUNT_POST_MESSAGE * AVERAGE_TX_PRICE)) {
                emit Error(
                    sender,
                    fromSchainID,
                    to,
                    amount,
                    data,
                    "Could not send money to owner"
                );
            }
            LockAndData(lockAndDataAddress).approveTransfer(to, amount - GAS_AMOUNT_POST_MESSAGE * AVERAGE_TX_PRICE);
        } else if (operation == TransactionOperation.transferERC20 || operation == TransactionOperation.rawTransferERC20) {
            address erc20Module = ContractManager(lockAndDataAddress).permitted(keccak256(abi.encodePacked("ERC20Module")));
            ERC20Module(erc20Module).sendERC20(to, data);
        } else if (operation == TransactionOperation.transferERC721 || operation == TransactionOperation.rawTransferERC721) {
            address erc721Module = ContractManager(lockAndDataAddress).permitted(keccak256(abi.encodePacked("ERC721Module")));
            ERC721Module(erc721Module).sendERC721(to, data);
        }
    }

    /**
     * @dev Convert first byte of data to Operation
     * 0x01 - transfer eth
     * 0x03 - transfer ERC20 token
     * 0x05 - transfer ERC721 token
     * 0x13 - transfer ERC20 token - raw mode
     * 0x15 - transfer ERC721 token - raw mode
     * @param data - received data
     * @return operation
     */
    function fallbackOperationTypeConvert(bytes memory data)
        internal
        pure
        returns (TransactionOperation)
    {
        bytes1 operationType;
        assembly {
            operationType := mload(add(data, 0x20))
        }
        require(
            operationType == 0x01 ||
            operationType == 0x03 ||
            operationType == 0x05 ||
            operationType == 0x13 ||
            operationType == 0x15,
            "Operation type is not identified"
        );
        if (operationType == 0x01) {
            return TransactionOperation.transferETH;
        } else if (operationType == 0x03) {
            return TransactionOperation.transferERC20;
        } else if (operationType == 0x05) {
            return TransactionOperation.transferERC721;
        } else if (operationType == 0x13) {
            return TransactionOperation.rawTransferERC20;
        } else if (operationType == 0x15) {
            return TransactionOperation.rawTransferERC721;
        }
    }
}