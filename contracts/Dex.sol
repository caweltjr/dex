// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.3;
pragma experimental ABIEncoderV2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/math/SafeMath.sol';

contract Dex {
    using SafeMath for uint;
    // for limit orders
    enum Side {
        BUY,
        SELL
    }
    struct Token{
        bytes32 ticker;
        address tokenAddress;
    }
    struct Order{
        uint id;
        address trader;
        Side side;
        bytes32 ticker;
        uint amount;
        uint filled;
        uint price;
        uint date;
    }
    event NewTrade(
        uint tradeId,
        uint orderId,
        bytes32 indexed ticker,
        address indexed trader1,
        address indexed trader2,
        uint amount,
        uint price,
        uint date
    );
    address public admin;
    uint public nextOrderId;
    uint public nextTradeId;
    bytes32 public nextTokenId;
    bytes32 constant DAI = bytes32('DAI');

    mapping(bytes32 => Token) public tokens;
    mapping(address => mapping(bytes32 => uint)) public traderBalances;//trader -> pointer to list of tokens -> balance of each token
    // order book - uint is cast - 0=buy,1=sell
    // bytes32 is always the token
    // each token will have an array of limit orders for buy and an array of limit orders for sell
    mapping(bytes32 => mapping(uint => Order[])) public orderBook;
    bytes32[] public tokenList;

    modifier onlyAdmin(){
        require(msg.sender == admin, 'Only Admin can do this');
        _;
    }
    modifier tokenExists(bytes32 _ticker){
        require(tokens[_ticker].tokenAddress != address(0), 'this token does not exist');
        _;
    }
    modifier tokenIsNotDai(bytes32 _ticker){
        require(_ticker != DAI, 'cannot trade DAI');
        _;
    }
    constructor() public {
        admin = msg.sender;
    }
    function getOrders(
        bytes32 ticker,
        Side side)
    external
    view
    returns(Order[] memory) {
        return orderBook[ticker][uint(side)];
    }

    function getTokens()
    external
    view
    returns(Token[] memory) {
        Token[] memory _tokens = new Token[](tokenList.length);
        for (uint i = 0; i < tokenList.length; i++) {
            _tokens[i] = Token(
                tokens[tokenList[i]].ticker,
                tokens[tokenList[i]].tokenAddress
            );
        }
        return _tokens;
    }
    function addToken(bytes32 _ticker, address _tokenAddress) onlyAdmin() external{
        tokens[_ticker] = Token(_ticker, _tokenAddress);
        tokenList.push(_ticker);
    }
    // users need to be able to send deposit/withdraw tokens on our exchange
    function deposit(uint amount, bytes32 ticker) external{
        IERC20(tokens[ticker].tokenAddress).transferFrom(msg.sender, address(this),amount);
        // use the Zeppelin SafeMath functions from now on
        traderBalances[msg.sender][ticker] = traderBalances[msg.sender][ticker].add(amount);
        //traderBalances[msg.sender][_ticker] += _amount;
    }
    function withdraw(uint amount, bytes32 ticker) tokenExists(ticker) external{
        require(traderBalances[msg.sender][ticker] >= amount,'Insufficient tokens for this withdrawal');
        IERC20(tokens[ticker].tokenAddress).transfer(msg.sender,amount);
        traderBalances[msg.sender][ticker] = traderBalances[msg.sender][ticker].sub(amount);
        //traderBalances[msg.sender][_ticker] -= _amount;
    }
    function createLimitOrder(bytes32 ticker, uint amount, uint price, Side side)
        tokenIsNotDai(ticker) tokenExists(ticker) external{
        // trader is going to use DAI to buy tokens, and will sell tokens for DAI
        // DAI is kept in the traderBalances array just like any other token
        // even though it is the token used to trade
        if(side == Side.SELL){
            // check the balance of the token that isn't DAI - bail if don't have enough of the tokens on
            //  hand to sell the amount of the limit order
            require(traderBalances[msg.sender][ticker] >= amount, 'token balance is too low');
        }else{
            // check the DAI balance - bail if not enough DAI to buy any more tokens
            require(traderBalances[msg.sender][DAI] >= amount.mul(price), 'DAI balance is too low');
        }
        Order[] storage orders = orderBook[ticker][uint(side)];
        orders.push(Order(nextOrderId,msg.sender,side,ticker,amount,0,price,block.timestamp));
        // keep the order array sorted using Bubble Sort
        uint i = orders.length - 1; // start at the bottom of the array
        while(i < 0){
            if(side == Side.BUY && orders[i-1].price > orders[i].price){// BUY stopping condition
                break; // gets out of while loop
            }
            if(side == Side.SELL && orders[i-1].price < orders[i].price){ // SELL stopping condition
                break;
            }
            Order memory tempOrder = orders[i-1];
            orders[i-1] = orders[i];
            orders[i] = tempOrder;
        }
        nextOrderId++;
    }
    function createMarketOrder(
        bytes32 ticker,
        uint amount,
        Side side)
    tokenExists(ticker)
    tokenIsNotDai(ticker)
    external {
        if(side == Side.SELL){
            require(traderBalances[msg.sender][ticker] >= amount, 'token balance is too low');
        }
        // get the other side of orders, i.e. if it's a BUY market order, get the list of SELL orders
        Order[] storage orders = orderBook[ticker][uint(side == Side.BUY ? Side.SELL : Side.BUY)];
        uint i;
        uint remaining = amount;
        while(i < orders.length && remaining > 0){
            //uint available = orders[i].amount - orders[i].filled;
            uint available = orders[i].amount.sub(orders[i].filled);
            uint matched = (remaining > available) ? available : remaining;
            //remaining -= matched;
            remaining = remaining.sub(matched);
            //orders[i].filled += matched;
            orders[i].filled = orders[i].filled.add(matched);

            emit NewTrade(nextTradeId,
                orders[i].id,
                ticker,
                orders[i].trader, // trader that created order in the orderbook
                msg.sender, // trader that is buying or selling
                matched,
                orders[i].price,
                block.timestamp);

            if(side == Side.SELL) {
                // msg.sender put in the order; his token balance goes down(he sold them) and his DAI goes up
                traderBalances[msg.sender][ticker] = traderBalances[msg.sender][ticker].sub(matched);
                traderBalances[msg.sender][DAI] = traderBalances[msg.sender][DAI].add(matched.mul(orders[i].price));
                // orders[i].trader is the one with the limit order in the order boot
                // his tokens go up(he bought them) and his DAI goes down
                traderBalances[orders[i].trader][ticker] = traderBalances[orders[i].trader][ticker].add(matched);
                traderBalances[orders[i].trader][DAI] = traderBalances[orders[i].trader][DAI].sub(matched.mul(orders[i].price));
            }
            if(side == Side.BUY) { // the opposite of above
                // sale may not go thru, msg.sender must have enough DAI to pay for this trade
                require(
                    traderBalances[msg.sender][DAI] >= matched.mul(orders[i].price),
                    'dai balance too low for BUY trade'
                );
                traderBalances[msg.sender][ticker] = traderBalances[msg.sender][ticker].add(matched);
                traderBalances[msg.sender][DAI] = traderBalances[msg.sender][DAI].sub(matched.mul(orders[i].price));
                traderBalances[orders[i].trader][ticker] = traderBalances[orders[i].trader][ticker].sub(matched);
                traderBalances[orders[i].trader][DAI] = traderBalances[orders[i].trader][DAI].add(matched.mul(orders[i].price));
            }
            nextTradeId++;
            i++;
        }
        i = 0;
        while(i < orders.length && (orders[i].filled == orders[i].amount)){
            for(uint j = i; j < orders.length - 1; j++ ) {
                orders[j] = orders[j + 1];
            }
            orders.pop();
            i++;
        }
    }
}
