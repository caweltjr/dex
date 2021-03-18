// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.3;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
//import '@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol';

//contract Bat is ERC20, ERC20Detailed {
contract Bat is ERC20 {
//  constructor() ERC20Detailed('BAT', 'Brave browser token', 18) public {}
  constructor() ERC20('BAT', 'Brave browser token') public {}

  function faucet(address to, uint amount) external {
    _mint(to, amount);
  }
}
