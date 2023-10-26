/// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.21;

import { ERC20 } from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

/// @title sERC20
/// @author Zeropoint Labs.
/// @dev Synthetic ERC20 tokens out of 1155a
contract sERC20 is ERC20 {
    address public immutable ERC1155A;
    uint8 private immutable tokenDecimals;

    error ONLY_ERC1155A();

    modifier onlyTokenSplitter() {
        if (msg.sender != ERC1155A) {
            revert ONLY_ERC1155A();
        }
        _;
    }

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_) {
        ERC1155A = msg.sender;
        tokenDecimals = decimals_;
    }

    function mint(address owner, uint256 amount) external onlyTokenSplitter {
        _mint(owner, amount);
    }

    function burn(address owner, address spender, uint256 amount) external onlyTokenSplitter {
        if (owner != spender) _spendAllowance(owner, spender, amount);

        _burn(owner, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return tokenDecimals;
    }
}
