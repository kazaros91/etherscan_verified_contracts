pragma solidity ^0.4.11;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a * b;
    assert(a == 0 || c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal constant returns (uint256) {
    // assert(b &gt; 0); // Solidity automatically throws when dividing by 0 uint256 c = a / b;
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn&#39;t hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal constant returns (uint256) {
    assert(b &lt;= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal constant returns (uint256) {
    uint256 c = a + b;
    assert(c &gt;= a);
    return c;
  }
}

/**
 * @title Crowdsale
 * @dev Crowdsale is a base contract for managing a token crowdsale.
 * Crowdsales have a start and end timestamps, where investors can make
 * token purchases and the crowdsale will assign them tokens based
 * on a token per ETH rate. Funds collected are forwarded to a wallet
 * as they arrive.
 */
contract token { function transfer(address receiver, uint amount){  } }
contract Crowdsale {
  using SafeMath for uint256;

  // uint256 durationInMinutes;
  // address where funds are collected
  address public wallet;
  // token address
  address public addressOfTokenUsedAsReward;

  uint256 public price = 300;
  uint256 public priceBeforeGoalReached;
  uint256 public tokensSoldGoal;
  uint256 public tokensSold;
  uint256 public minBuy;
  uint256 public maxBuy;

  token tokenReward;

  // mapping (address =&gt; uint) public contributions;
  


  // start and end timestamps where investments are allowed (both inclusive)
  uint256 public startTime;
  // uint256 public endTime;
  // amount of raised money in wei
  uint256 public weiRaised;

  /**
   * event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);


  function Crowdsale() {
    //You will change this to your wallet where you need the ETH 
    wallet = 0xD975c18B7B9e6a0821cD86126705f9544B6e392d;
    // durationInMinutes = _durationInMinutes;
    //Here will come the checksum address we got
    addressOfTokenUsedAsReward = 0x2f5381bA547332d2a972189B5a4bB895A32aE4B6;


    tokenReward = token(addressOfTokenUsedAsReward);
  }

  bool public started = false;

  function startSale(uint256 _delayInMinutes){
    if (msg.sender != wallet) throw;
    startTime = now + _delayInMinutes*1 minutes;
    started = true;
  }

  function stopSale(){
    if(msg.sender != wallet) throw;
    started = false;
  }

  function setPrice(uint256 _price){
    if(msg.sender != wallet) throw;
    price = _price;
  }

  function setMinBuy(uint256 _minBuy){
    if(msg.sender!=wallet) throw;
    minBuy = _minBuy;
  }

  function setMaxBuy(uint256 _maxBuy){
    if(msg.sender != wallet) throw;
    maxBuy = _maxBuy;
  }

  function changeWallet(address _wallet){
  	if(msg.sender != wallet) throw;
  	wallet = _wallet;
  }

  function changeTokenReward(address _token){
    if(msg.sender!=wallet) throw;
    tokenReward = token(_token);
  }

  function setTokensSoldGoal(uint256 _goal){
    if(msg.sender!=wallet) throw;
    tokensSoldGoal = _goal;
  }

  function setPriceBeforeGoalReached(uint256 _price){
    if(msg.sender!=wallet) throw;
    priceBeforeGoalReached = _price;
  }

  // fallback function can be used to buy tokens
  function () payable {
    buyTokens(msg.sender);
  }

  // low level token purchase function
  function buyTokens(address beneficiary) payable {
    require(beneficiary != 0x0);
    require(validPurchase());

    uint256 weiAmount = msg.value;

    if(weiAmount &lt; 10**17) throw;

    // calculate token amount to be sent
    uint256 tokens;

    if (tokensSoldGoal&gt;0&amp;&amp;tokensSold&lt;tokensSoldGoal*10**18)
      tokens = (weiAmount) * priceBeforeGoalReached; 
    else tokens = (weiAmount) * price;
    
    if(minBuy!=0){
      if(tokens &lt; minBuy*10**18) throw;
    }

    if(maxBuy!=0){
      if(tokens &gt; maxBuy*10**18) throw;
    }

    // update state
    weiRaised = weiRaised.add(weiAmount);
    tokensSold = tokensSold.add(tokens);
    
    // if(contributions[msg.sender].add(weiAmount)&gt;10*10**18) throw;
    // contributions[msg.sender] = contributions[msg.sender].add(weiAmount);

    tokenReward.transfer(beneficiary, tokens);
    TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
    forwardFunds();
  }

  // send ether to the fund collection wallet
  // override to create custom fund forwarding mechanisms
  function forwardFunds() internal {
    // wallet.transfer(msg.value);
    if (!wallet.send(msg.value)) {
      throw;
    }
  }

  // @return true if the transaction can buy tokens
  function validPurchase() internal constant returns (bool) {
    bool withinPeriod = started&amp;&amp;(now&gt;=startTime);
    bool nonZeroPurchase = msg.value != 0;
    return withinPeriod &amp;&amp; nonZeroPurchase;
  }

  function withdrawTokens(uint256 _amount) {
    if(msg.sender!=wallet) throw;
    tokenReward.transfer(wallet,_amount);
  }
}