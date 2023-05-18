/// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";

/**
 * @title ERC1155S
 * @dev ERC1155S is a SuperForm specific extension for ERC1155.
 *
 * 1. Single id approve capability
 * 2. Allowance management for single id approve
 * 3. Metadata build out of baseURI and superformId uint value into offchain metadata address
 *
 */

abstract contract ERC1155s is ERC1155 {
    /// @notice Event emitted when single id approval is set
    event ApprovalForOne(
        address indexed owner,
        address indexed spender,
        uint256 id,
        uint256 amount
    );

    /// @notice ERC20-like mapping for single id approvals
    mapping(address owner => mapping(address spender => mapping(uint256 id => uint256 amount)))
        private allowances;


    constructor(string memory uri_) ERC1155(uri_) {}

    ///////////////////////////////////////////////////////////////////////////
    ///                     ERC1155-S LOGIC SECTION                         ///
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Transfer singleApproved id with this function
    /// @dev If caller is owner of ids, transfer just executes.
    /// @dev If caller singleApproved > transferAmount, function executes and reduces allowance (even if setApproveForAll is true)
    /// @dev If caller singleApproved < transferAmount && isApprovedForAll, function executes without reducing allowance (full trust assumed)
    /// @dev If caller only approvedForAll, function executes without reducing allowance (full trust assumed)
    /// @dev SingleApprove is senior in execution flow, but isApprovedForAll is senior in allowance management
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        address operator = msg.sender;
        uint256 allowed = allowances[from][operator][id];

        /// NOTE: This function order makes it more costly to use isApprovedForAll but cheaper to user single approval and owner transfer

        /// @dev operator is an owner of ids
        if (operator == from) {
            /// @dev no need to self-approve
            /// @dev make transfer
            _safeTransferFrom(operator, from, to, id, amount, data);

            /// @dev operator allowance is higher than requested amount
        } else if (allowed >= amount) {
            /// @dev decrease allowance
            _decreaseAllowance(from, operator, id, amount);
            /// @dev make transfer
            _safeTransferFrom(operator, from, to, id, amount, data);

            /// @dev operator is approved for all tokens
        } else if (isApprovedForAll(from, operator)) {
            /// NOTE: We don't decrease individual allowance here.
            /// NOTE: Spender effectively has unlimited allowance because of isApprovedForAll
            /// NOTE: We leave allowance management to token owners

            /// @dev make transfer
            _safeTransferFrom(operator, from, to, id, amount, data);

            /// @dev operator is not an owner of ids or not enough of allowance, or is not approvedForAll
        } else {
            revert("NOT_AUTHORIZED");
        }
    }

    /// @notice Transfer batch of ids with this function
    /// @dev Ignores single id approvals. Works only with setApprovalForAll.
    /// @dev Assumption is that BatchTransfers are supposed to be gas-efficient
    /// @dev Assumption is that ApprovedForAll operator is also trusted for any other allowance amount existing as singleApprove
    /// NOTE: Additional option may be range-based approvals
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /// @notice Internal safeTranferFrom function called after all checks from the public function are done
    function _safeTransferFrom(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        _safeTransferFrom( from, to, id, amount, data);
    }

    ///////////////////////////////////////////////////////////////////////////
    ///                     SIGNLE APPROVE SECTION                          ///
    ///////////////////////////////////////////////////////////////////////////

    /// @notice Public function for setting single id approval
    /// @dev Notice `owner` param, it will always be msg.sender, see _setApprovalForOne()
    function setApprovalForOne(
        address spender,
        uint256 id,
        uint256 amount
    ) public virtual {
        address owner = msg.sender;
        _setApprovalForOne(owner, spender, id, amount);
    }

    /// @notice Public getter for existing single id approval
    /// @dev Re-adapted from ERC20
    function allowance(
        address owner,
        address spender,
        uint256 id
    ) public view virtual returns (uint256) {
        return allowances[owner][spender][id];
    }

    /// @notice Public function for increasing single id approval amount
    /// @dev Re-adapted from ERC20
    function increaseAllowance(
        address spender,
        uint256 id,
        uint256 addedValue
    ) public virtual returns (bool) {
        address owner = msg.sender;
        _setApprovalForOne(
            owner,
            spender,
            id,
            allowance(owner, spender, id) + addedValue
        );
        return true;
    }

    /// @notice Public function for decreasing single id approval amount
    /// @dev Re-adapted from ERC20
    function decreaseAllowance(
        address spender,
        uint256 id,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        address owner = msg.sender;
        uint256 currentAllowance = allowance(owner, spender, id);
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _setApprovalForOne(
                owner,
                spender,
                id,
                currentAllowance - subtractedValue
            );
        }

        return true;
    }

    /// @notice Internal function for decreasing single id approval amount
    /// @dev Only to be used by address(this)
    /// @dev Notice `owner` param, only contract functions should be able to define it
    /// @dev Re-adapted from ERC20
    function _decreaseAllowance(
        address owner,
        address spender,
        uint256 id,
        uint256 subtractedValue
    ) internal virtual returns (bool) {
        uint256 currentAllowance = allowance(owner, spender, id);
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _setApprovalForOne(
                owner,
                spender,
                id,
                currentAllowance - subtractedValue
            );
        }

        return true;
    }

    /// @notice Internal function for setting single id approval
    /// @dev Used for fine-grained control over approvals with increase/decrease allowance
    /// @dev Notice `owner` param, only contract functions should be able to define it
    function _setApprovalForOne(
        address owner,
        address spender,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        allowances[owner][spender][id] = amount;
        emit ApprovalForOne(owner, spender, id, amount);
    }

    ///////////////////////////////////////////////////////////////////////////
    ///                        METADATA SECTION                             ///
    ///////////////////////////////////////////////////////////////////////////

    /// @notice See {IERC721Metadata-tokenURI}.
    /// @dev Compute return string from baseURI set for this contract and unique vaultId
    function uri(
        uint256 superFormId
    ) public view virtual override returns (string memory) {
        return
            string(abi.encodePacked(_baseURI(), Strings.toString(superFormId)));
    }

    /// @dev Used to construct return url
    function _baseURI() internal view virtual returns (string memory);
}

/// @notice A generic interface for a contract which properly accepts ERC1155 tokens.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/tokens/ERC1155.sol)
abstract contract ERC1155TokenReceiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external virtual returns (bytes4) {
        return ERC1155TokenReceiver.onERC1155BatchReceived.selector;
    }
}
