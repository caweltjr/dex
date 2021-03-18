// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.3;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
//import '@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol';

//contract Rep is ERC20, ERC20Detailed {
contract Rep is ERC20 {
//  constructor() ERC20Detailed('REP', 'Augur token', 18) public {}
  constructor() ERC20('REP', 'Augur token') public {}

  function faucet(address to, uint amount) external {
    _mint(to, amount);
  }
}
