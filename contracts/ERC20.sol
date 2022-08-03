// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20FlashMint.sol";

contract MyToken is ERC20, Ownable, ERC20FlashMint {

// Enter staking contract address to store token for giving reward
 constructor() ERC20("MyToken", "MTK") {}

    // call the approve function first to allow staking contract to use token 
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
