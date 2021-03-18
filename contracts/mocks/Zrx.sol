// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.3;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
// remove the next - google says it's in the above
//import '@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol';

//contract Zrx is ERC20, ERC20Detailed {
contract Zrx is ERC20 {
//  constructor() ERC20Detailed('ZRX', '0x token', 18) public {}
  constructor() ERC20('ZRX', '0x token') public {}

  function faucet(address to, uint amount) external {
    _mint(to, amount);
  }
}
