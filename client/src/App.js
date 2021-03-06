import React, { useState, useEffect } from "react";
import Header from './Header.js';
import Footer from './Footer.js';
import Wallet from './Wallet.js';
import NewOrder from './NewOrder.js';
import AllOrders from './AllOrders.js';
import MyOrders from './MyOrders.js';
import AllTrades from './AllTrades.js';
const cc = require("cryptocompare");
cc.setApiKey('<0b8a57ae808ed4d8253b10c54360b29ad6b1bd2c607d17852bb7f7c9f16fca7f>')

const SIDE = {
  BUY: 0,
  SELL: 1
};

function App({web3, accounts, contracts}) {
  const [tokens, setTokens]  = useState([]);
  const [user, setUser] = useState({
    accounts: [], 
    balances: {
      tokenDex: 0,
      tokenWallet: 0
    },
    selectedToken: undefined
  });
  const [orders, setOrders] = useState({
    buy: [],
    sell: []
  });
  const [trades, setTrades] = useState([]);
  const [listener, setListener] = useState(undefined);

  // const fetchCoins = async () => {
  //   let coinList = (await cc.coinList()).Data;
  //   console.log("Coin List = ", coinList);
  //   return {coinList};
  // }
  const getBalances = async (account, token) => {
    const tokenDex = await contracts.dex.methods
      .traderBalances(account, web3.utils.fromAscii(token.ticker))
      .call();
    const tokenWallet = await contracts[token.ticker].methods
      .balanceOf(account)
      .call();
    return {tokenDex, tokenWallet};
  }

  const getOrders = async token => {
    const orders = await Promise.all([
      contracts.dex.methods
        .getOrders(web3.utils.fromAscii(token.ticker), SIDE.BUY)
        .call(),
      contracts.dex.methods
        .getOrders(web3.utils.fromAscii(token.ticker), SIDE.SELL)
        .call(),
    ]);
    return {buy: orders[0], sell: orders[1]};
  }

  const listenToTrades = token => {
    const tradeIds = new Set();// sets store unique values of any type - Javascript built-in
    setTrades([]);
    const listener = contracts.dex.events.NewTrade(
      {
        filter: {ticker: web3.utils.fromAscii(token.ticker)},
        fromBlock: 0
      })
      .on('data', newTrade => {
        if(tradeIds.has(newTrade.returnValues.tradeId)) return;
        tradeIds.add(newTrade.returnValues.tradeId);
        setTrades(trades => ([...trades, newTrade.returnValues]));
      });
    setListener(listener);
  }

  useEffect(() => {
    const init = async () => {
      const [balances, orders] = await Promise.all([
        getBalances(
          user.accounts[0], 
          user.selectedToken
        ),
        getOrders(user.selectedToken),
      ]);
      listenToTrades(user.selectedToken);
      setUser(user => ({ ...user, balances}));
      setOrders(orders);
    }
    if(typeof user.selectedToken !== 'undefined') {
      init();
    }
  }, [user.selectedToken], () => {
    listener.unsubscribe();
  });

  const selectToken = token => {
    setUser(user => ({ ...user, selectedToken: token}));
  }

  const deposit = async amount => {
    await contracts[user.selectedToken.ticker].methods
      .approve(contracts.dex.options.address, amount)
      .send({from: user.accounts[0]});
    await contracts.dex.methods
      .deposit(amount, web3.utils.fromAscii(user.selectedToken.ticker))
      .send({from: user.accounts[0]});
    const balances = await getBalances(
      user.accounts[0],
      user.selectedToken
    );
    setUser(user => ({ ...user, balances}));
  }

  const withdraw = async amount => {
    await contracts.dex.methods
      .withdraw(
        amount, 
        web3.utils.fromAscii(user.selectedToken.ticker)
      )
      .send({from: user.accounts[0]});
    const balances = await getBalances(
      user.accounts[0],
      user.selectedToken
    );
    setUser(user => ({ ...user, balances}));
  }

  const createMarketOrder = async (amount, side) => {
    await contracts.dex.methods
      .createMarketOrder(
        web3.utils.fromAscii(user.selectedToken.ticker),
        amount,
        side
      )
      .send({from: user.accounts[0]});
    const orders = await getOrders(user.selectedToken);
    setOrders(orders);
  }

  const createLimitOrder = async (amount, price, side) => {
    await contracts.dex.methods
      .createLimitOrder(
        web3.utils.fromAscii(user.selectedToken.ticker),
        amount,
        price,
        side
      )
      .send({from: user.accounts[0]});
    const orders = await getOrders(user.selectedToken);
    setOrders(orders);
  }

  useEffect(() => {
    const init = async () => {
      const ccxt = require ('ccxt')
          , HttpsProxyAgent = require ('https-proxy-agent')
      const proxy = 'http://localhost:3000/\'' // HTTP/HTTPS proxy to connect to
      console.log (ccxt.exchanges); // print all available exchanges
      await (async function () {
        const phemex = new ccxt.phemex ({ proxy });
        let describe = phemex.describe();
        console.log("describe = ", describe);
        console.log(phemex.commonCurrencies)
      })();
      //   let bitfinex = new ccxt.bitfinex({verbose: true})
      //   let huobipro = new ccxt.huobipro()
      //   let okcoinusd = new ccxt.okcoinusd({
      //     apiKey: 'YOUR_PUBLIC_API_KEY',
      //     secret: 'YOUR_SECRET_PRIVATE_KEY',
      //   })
      //
      //   const exchangeId = 'binance'
      //       , exchangeClass = ccxt[exchangeId]
      //       , exchange = new exchangeClass({
      //     'apiKey': 'YOUR_API_KEY',
      //     'secret': 'YOUR_SECRET',
      //     'timeout': 30000,
      //     'enableRateLimit': true,
      //   })
      //
      //   console.log(kraken.id, await kraken.loadMarkets())
      //   console.log(bitfinex.id, await bitfinex.loadMarkets())
      //   console.log(huobipro.id, await huobipro.loadMarkets())
      //
      //    console.log(kraken.id, await kraken.fetchOrderBook(kraken.symbols[0]))
      //   console.log(bitfinex.id, await bitfinex.fetchTicker('BTC/USD'))
      //   console.log(huobipro.id, await huobipro.fetchTrades('ETH/USDT'))
      //
      //   console.log(okcoinusd.id, await okcoinusd.fetchBalance())
      // })();
      // let coinList = (await cc.coinList()).Data;

      // let coins = [];
      // let i = 0;
      // for (const key of Object.keys(coinList)) {
      //   if(key === "BTC"){
      //     coins[i] = coinList[key].Symbol;
      //     console.log(coins[i])
      //     let priceData = await cc.price(coins[i], 'USD');
      //     console.log("Price = ", priceData);
      //     i++;
      //   }
      // }
      // get all the coin names and map the symbol to the name
      // let coinIds = coinSymbols.map(sym => coinList[sym]);
      const rawTokens = await contracts.dex.methods.getTokens().call();
      const tokens = rawTokens.map((token, i) => {
        return {...token, ticker: web3.utils.hexToUtf8(token.ticker)};
      });
      const [balances, orders] = await Promise.all([
        getBalances(accounts[0], tokens[0]),
        getOrders(tokens[0]),
      ]);
      listenToTrades(tokens[0])
      setTokens(tokens);
      setUser({accounts, balances, selectedToken: tokens[0]});
      setOrders(orders);
    }
    init();
  // eslint-disable-next-line
  }, []);

  const isReady = () => {
    return (
      typeof web3 !== 'undefined' 
      && typeof contracts !== 'undefined'
      && typeof user.selectedToken !== 'undefined'
    );
  }

  if (!isReady()) {
    return <div>Loading...</div>;
  }

  return (
    <div id="app">
      <Header 
        contracts={contracts}
        tokens={tokens}
        user={user}
        selectToken={selectToken}
      />
      <main className="container-fluid">
        <div className="row">
          <div className="col-sm-4 first-col">
            <Wallet 
              user={user}
              deposit={deposit}
              withdraw={withdraw}
            />
            {user.selectedToken.ticker !== 'DAI' ? (
              <NewOrder 
                createMarketOrder={createMarketOrder}
                createLimitOrder={createLimitOrder}
              />
            ) : null}
          </div>
          {user.selectedToken.ticker !== 'DAI' ? (
            <div className="col-sm-8">
                <AllTrades 
                  trades={trades}
                />
                <AllOrders 
                  orders={orders}
                />
                <MyOrders 
                  orders={{
                    buy: orders.buy.filter(
                      order => order.trader.toLowerCase() === accounts[0].toLowerCase()
                    ),
                    sell: orders.sell.filter(
                      order => order.trader.toLowerCase() === accounts[0].toLowerCase()
                    )
                  }}
                />
            </div>
          ) : null}
        </div>
      </main>
      <Footer />
    </div>
  );
}

export default App;
