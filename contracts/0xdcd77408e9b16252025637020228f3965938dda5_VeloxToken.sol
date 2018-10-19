pragma solidity ^0.4.24;


/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 _a, uint256 _b) internal pure returns (uint256 c) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (_a == 0) {
      return 0;
    }

    c = _a * _b;
    assert(c / _a == _b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
    // assert(_b > 0); // Solidity automatically throws when dividing by 0
    // uint256 c = _a / _b;
    // assert(_a == _b * c + _a % _b); // There is no case in which this doesn't hold
    return _a / _b;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {
    assert(_b <= _a);
    return _a - _b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 _a, uint256 _b) internal pure returns (uint256 c) {
    c = _a + _b;
    assert(c >= _a);
    return c;
  }
}


/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
  address public owner;


  event OwnershipRenounced(address indexed previousOwner);
  event OwnershipTransferred(
    address indexed previousOwner,
    address indexed newOwner
  );


  /**
   * @dev The Ownable constructor sets the original `owner` of the contract to the sender
   * account.
   */
  constructor() public {
    owner = msg.sender;
  }

  /**
   * @dev Throws if called by any account other than the owner.
   */
  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  /**
   * @dev Allows the current owner to relinquish control of the contract.
   * @notice Renouncing to ownership will leave the contract without an owner.
   * It will not be possible to call the functions with the `onlyOwner`
   * modifier anymore.
   */
  function renounceOwnership() public onlyOwner {
    emit OwnershipRenounced(owner);
    owner = address(0);
  }

  /**
   * @dev Allows the current owner to transfer control of the contract to a newOwner.
   * @param _newOwner The address to transfer ownership to.
   */
  function transferOwnership(address _newOwner) public onlyOwner {
    _transferOwnership(_newOwner);
  }

  /**
   * @dev Transfers control of the contract to a newOwner.
   * @param _newOwner The address to transfer ownership to.
   */
  function _transferOwnership(address _newOwner) internal {
    require(_newOwner != address(0));
    emit OwnershipTransferred(owner, _newOwner);
    owner = _newOwner;
  }
}


/**
 * @title ERC20Basic
 * @dev Simpler version of ERC20 interface
 * See https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
  function totalSupply() public view returns (uint256);
  function balanceOf(address _who) public view returns (uint256);
  function transfer(address _to, uint256 _value) public returns (bool);
  event Transfer(address indexed from, address indexed to, uint256 value);
}


/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
  function allowance(address _owner, address _spender)
    public view returns (uint256);

  function transferFrom(address _from, address _to, uint256 _value)
    public returns (bool);

  function approve(address _spender, uint256 _value) public returns (bool);
  event Approval(
    address indexed owner,
    address indexed spender,
    uint256 value
  );
}


/**
 * @title VeloxToken
 * @dev VeloxCoin => VeloxToken ERC20 token contract
 * This contract supports POS-style staking
 */
contract VeloxToken is ERC20, Ownable {
    using SafeMath for uint256;

    string public constant name = "Velox";
    string public constant symbol = "VLX";
    uint8 public constant decimals = 2;

    uint256 public constant STAKE_MIN_AGE = 64 seconds * 20; // 64 second block time * 20 blocks
    uint256 public constant STAKE_APR = 13; // 13% annual interest
    uint256 public constant MAX_TOTAL_SUPPLY = 100 * (10 ** (6 + uint256(decimals))); // 100 million tokens
    
    bool public balancesInitialized = false;
    
    struct transferIn {
        uint64 amount;
        uint64 time;
    }

    mapping (address => uint256) private balances;
    mapping (address => mapping (address => uint256)) private allowed;
    mapping (address => transferIn[]) transferIns;
    uint256 private totalSupply_;

    event Mint(address indexed to, uint256 amount);

    modifier canMint() {
        require(totalSupply_ < MAX_TOTAL_SUPPLY);
        _;
    }

    /**
     * @dev Constructor to set totalSupply_
     */
    constructor() public {
        totalSupply_ = 0;
    }

    /**
     * @dev POS-style staking reward mint function
     */
    function mint() public canMint returns (bool) {
        if (balances[msg.sender] <= 0) return false;
        if (transferIns[msg.sender].length <= 0) return false;

        uint reward = _getStakingReward(msg.sender);
        if (reward <= 0) return false;

        _mint(msg.sender, reward);
        emit Mint(msg.sender, reward);
        return true;
    }

    /**
     * @dev External coin age computation function
     */
    function getCoinAge() external view returns (uint256) {
        return _getCoinAge(msg.sender, block.timestamp);
    }

    /**
     * @dev Internal staking reward computation function
     * @return An uint256 representing the sum of coin ages times interest rate
     */
    function _getStakingReward(address _address) internal view returns (uint256) {
        uint256 coinAge = _getCoinAge(_address, block.timestamp); // Sum (value * days since tx arrived)
        if (coinAge <= 0) return 0;
        return (coinAge * STAKE_APR).div(365 * 100); // Amount to deliver in this interval to user
    }

    /**
     * @dev Internal coin age computation function
     * @return An uint256 representing the sum of all coin ages (value * days since tx arrived for each utxo)
     */
    function _getCoinAge(address _address, uint256 _now) internal view returns (uint256 _coinAge) {
        if (transferIns[_address].length <= 0) return 0;

        for (uint256 i = 0; i < transferIns[_address].length; i++) {
            if (_now < uint256(transferIns[_address][i].time).add(STAKE_MIN_AGE)) continue;
            uint256 coinSeconds = _now.sub(uint256(transferIns[_address][i].time));
            _coinAge = _coinAge.add(uint256(transferIns[_address][i].amount).mul(coinSeconds).div(1 days));
        }
    }

    /**
     * @dev Function to init balances mapping on token launch
     */
    function initBalances(address[] _accounts, uint64[] _amounts) external onlyOwner {
        require(!balancesInitialized);
        require(_accounts.length > 0 && _accounts.length == _amounts.length);

        uint256 total = 0;
        for (uint256 i = 0; i < _amounts.length; i++) total = total.add(uint256(_amounts[i]));
        require(total <= MAX_TOTAL_SUPPLY);

        for (uint256 j = 0; j < _accounts.length; j++) _mint(_accounts[j], uint256(_amounts[j]));
    }

    /**
     * @dev Function to complete initialization of token balances after launch
     */
    function completeInitialization() external onlyOwner {
        require(!balancesInitialized);
        balancesInitialized = true;
    }

    /**
     * @dev Total number of tokens in existence
     */
    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    /**
     * @dev Gets the balance of the specified address.
     * @param _owner The address to query the the balance of.
     * @return An uint256 representing the amount owned by the passed address.
     */
    function balanceOf(address _owner) public view returns (uint256) {
        return balances[_owner];
    }

    /**
     * @dev Function to check the amount of tokens that an owner allowed to a spender.
     * @param _owner address The address which owns the funds.
     * @param _spender address The address which will spend the funds.
     * @return A uint256 specifying the amount of tokens still available for the spender.
     */
    function allowance(
        address _owner,
        address _spender
    )
        public
        view
        returns (uint256)
    {
        return allowed[_owner][_spender];
    }

    /**
     * @dev Transfer token for a specified address
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     */
    function transfer(address _to, uint256 _value) public returns (bool) {
        if (msg.sender == _to) return mint();
        require(_value <= balances[msg.sender]);
        require(_to != address(0));

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        if (transferIns[msg.sender].length > 0) delete transferIns[msg.sender];
        uint64 time = uint64(block.timestamp);
        transferIns[msg.sender].push(transferIn(uint64(balances[msg.sender]), time));
        transferIns[_to].push(transferIn(uint64(_value), time));
        return true;
    }

    /**
     * @dev Transfer tokens to multiple addresses
     * @param _to The addresses to transfer to.
     * @param _values The amounts to be transferred.
     */
    function batchTransfer(address[] _to, uint256[] _values) public returns (bool) {
        require(_to.length == _values.length);
        for (uint256 i = 0; i < _to.length; i++) require(transfer(_to[i], _values[i]));
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param _spender The address which will spend the funds.
     * @param _value The amount of tokens to be spent.
     */
    function approve(address _spender, uint256 _value) public returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * @dev Transfer tokens from one address to another
     * @param _from address The address which you want to send tokens from
     * @param _to address The address which you want to transfer to
     * @param _value uint256 the amount of tokens to be transferred
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    )
        public
        returns (bool)
    {
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);
        require(_to != address(0));

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        if (transferIns[_from].length > 0) delete transferIns[_from];
        uint64 time = uint64(block.timestamp);
        transferIns[_from].push(transferIn(uint64(balances[_from]), time));
        transferIns[_to].push(transferIn(uint64(_value), time));
        return true;
    }

    /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     * approve should be called when allowed[_spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * @param _spender The address which will spend the funds.
     * @param _addedValue The amount of tokens to increase the allowance by.
     */
    function increaseApproval(
        address _spender,
        uint256 _addedValue
    )
        public
        returns (bool)
    {
        allowed[msg.sender][_spender] = (
        allowed[msg.sender][_spender].add(_addedValue));
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /**
     * @dev Decrease the amount of tokens that an owner allowed to a spender.
     * approve should be called when allowed[_spender] == 0. To decrement
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * @param _spender The address which will spend the funds.
     * @param _subtractedValue The amount of tokens to decrease the allowance by.
     */
    function decreaseApproval(
        address _spender,
        uint256 _subtractedValue
    )
        public
        returns (bool)
    {
        uint256 oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue >= oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /**
     * @dev Internal function that mints an amount of the token and assigns it to
     * an account. This encapsulates the modification of balances such that the
     * proper events are emitted.
     * @param _account The account that will receive the created tokens.
     * @param _amount The amount that will be created.
     */
    function _mint(address _account, uint256 _amount) internal {
        require(_account != 0);
        totalSupply_ = totalSupply_.add(_amount);
        balances[_account] = balances[_account].add(_amount);
        if (transferIns[_account].length > 0) delete transferIns[_account];
        transferIns[_account].push(transferIn(uint64(balances[_account]), uint64(block.timestamp)));
        emit Transfer(address(0), _account, _amount);
    }
}