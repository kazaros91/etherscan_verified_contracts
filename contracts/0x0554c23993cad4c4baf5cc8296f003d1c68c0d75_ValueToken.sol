pragma solidity ^0.4.18;

library SafeMath {
    function add(uint a, uint b) internal pure returns (uint c) {
        c = a + b;
        assert(c &gt;= a);
    }
    function sub(uint a, uint b) internal pure returns (uint c) {
        assert(b &lt;= a);
        c = a - b;
    }
    function mul(uint a, uint b) internal pure returns (uint c) {
        c = a * b;
        assert(a == 0 || c / a == b);
    }
    function div(uint a, uint b) internal pure returns (uint c) {
        assert(b &gt; 0);
        c = a / b;
        assert(a == b * c + a % b);
    }
}

contract ownable {
    address public owner;

    function ownable() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner public {
        owner = newOwner;
    }

    function isOwner(address _owner) internal view returns (bool) {
        return owner == _owner;
    }
}

contract Pausable is ownable {
    bool public paused = false;
    
    event Pause();
    event Unpause();
    
    modifier whenNotPaused() {
        require(!paused);
        _;
    }
    
    modifier whenPaused() {
        require(paused);
        _;
    }
    
    function pause() onlyOwner whenNotPaused public returns (bool success) {
        paused = true;
        Pause();
        return true;
    }
  
    function unpause() onlyOwner whenPaused public returns (bool success) {
        paused = false;
        Unpause();
        return true;
    }
}

contract Lockable is Pausable {
    mapping (address =&gt; bool) public locked;
    
    event Lockup(address indexed target);
    event UnLockup(address indexed target);
    
    function lockup(address _target) onlyOwner public returns (bool success) {
        require(!isOwner(_target));
        locked[_target] = true;
        Lockup(_target);
        return true;
    }

    function unlockup(address _target) onlyOwner public returns (bool success) {
        require(!isOwner(_target));
        delete locked[_target];
        UnLockup(_target);
        return true;
    }
    
    function isLockup(address _target) internal view returns (bool) {
        if(true == locked[_target])
            return true;
    }
}

interface tokenRecipient { function receiveApproval(address _from, uint256 _value, address _token, bytes _extraData) external; }

contract TokenERC20 {
    using SafeMath for uint;

    string public name;
    string public symbol;
    uint8 public decimals = 18;
    
    // 18 decimals is the strongly suggested default, avoid changing it
    uint256 public totalSupply;

    // This creates an array with all balances
    mapping (address =&gt; uint256) public balanceOf;
    mapping (address =&gt; mapping (address =&gt; uint256)) public allowance;

    // This generates a public event on the blockchain that will notify clients
    event Transfer(address indexed from, address indexed to, uint256 value);
    // This generates a public event on the blockchain that will notify clients
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
    // This notifies clients about the amount burnt
    event Burn(address indexed from, uint256 value);

    /**
     * Constrctor function
     * Initializes contract with initial supply tokens to the creator of the contract
     */
    function TokenERC20 (
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) public {
        totalSupply = initialSupply * 10 ** uint256(decimals);  // Update total supply with the decimal amount
        balanceOf[msg.sender] = totalSupply;                // Give the creator all initial tokens
        name = tokenName;                                   // Set the name for display purposes
        symbol = tokenSymbol;                               // Set the symbol for display purposes
    }

    /**
     * Internal transfer, only can be called by this contract
     */
    function _transfer(address _from, address _to, uint _value) internal {
        // Prevent transfer to 0x0 address. Use burn() instead
        require(_to != 0x0);
        // Check if the sender has enough
        require(balanceOf[_from] &gt;= _value);
        // Check for overflows
        require(SafeMath.add(balanceOf[_to], _value) &gt; balanceOf[_to]);

        // Save this for an assertion in the future
        uint previousBalances = SafeMath.add(balanceOf[_from], balanceOf[_to]);
        // Subtract from the sender
        balanceOf[_from] = SafeMath.sub(balanceOf[_from], _value);
        // Add the same to the recipient
        balanceOf[_to] = SafeMath.add(balanceOf[_to], _value);

        Transfer(_from, _to, _value);
        // Asserts are used to use static analysis to find bugs in your code. They should never fail
        assert(SafeMath.add(balanceOf[_from], balanceOf[_to]) == previousBalances);
    }

    /**
     * Transfer tokens
     * Send `_value` tokens to `_to` from your account
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transfer(address _to, uint256 _value) public returns (bool success) {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    /**
     * Transfer tokens from other address
     * Send `_value` tokens to `_to` in behalf of `_from`
     * @param _from The address of the sender
     * @param _to The address of the recipient
     * @param _value the amount to send
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        require(_value &lt;= allowance[_from][msg.sender]);
        allowance[_from][msg.sender] = SafeMath.sub(allowance[_from][msg.sender], _value);
        _transfer(_from, _to, _value);
        return true;
    }

    /**
     * Set allowance for other address
     *
     * Allows `_spender` to spend no more than `_value` tokens in your behalf
     *
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     */
    function approve(address _spender, uint256 _value) public
        returns (bool success) {
        allowance[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }

    /**
     * Set allowance for other address and notify
     * Allows `_spender` to spend no more than `_value` tokens in your behalf, and then ping the contract about it
     * @param _spender The address authorized to spend
     * @param _value the max amount they can spend
     * @param _extraData some extra information to send to the approved contract
     */
    function approveAndCall(address _spender, uint256 _value, bytes _extraData)
        public
        returns (bool success) {
        tokenRecipient spender = tokenRecipient(_spender);
        if (approve(_spender, _value)) {
            spender.receiveApproval(msg.sender, _value, this, _extraData);
            return true;
        }
    }

    /**
     * Destroy tokens
     * Remove `_value` tokens from the system irreversibly
     * @param _value the amount of money to burn
     */
    function burn(uint256 _value) public returns (bool success) {
        require(balanceOf[msg.sender] &gt;= _value);                               // Check if the sender has enough
        balanceOf[msg.sender] = SafeMath.sub(balanceOf[msg.sender], _value);    // Subtract from the sender
        totalSupply = SafeMath.sub(totalSupply, _value);                        // Updates totalSupply
        Burn(msg.sender, _value);
        return true;
    }

    /**
     * Destroy tokens from other account
     *
     * Remove `_value` tokens from the system irreversibly on behalf of `_from`.
     *
     * @param _from the address of the sender
     * @param _value the amount of money to burn
     */
    function burnFrom(address _from, uint256 _value) public returns (bool success) {
        require(balanceOf[_from] &gt;= _value);                        // Check if the targeted balance is enough
        require(_value &lt;= allowance[_from][msg.sender]);            // Check allowance
        balanceOf[_from] = SafeMath.sub(balanceOf[_from], _value);  // Subtract from the targeted balance
        allowance[_from][msg.sender] = SafeMath.sub(allowance[_from][msg.sender], _value); // Subtract from the sender&#39;s allowance
        totalSupply = SafeMath.sub(totalSupply, _value);            // Update totalSupply
        Burn(_from, _value);
        return true;
    }
}

contract ValueToken is Lockable, TokenERC20 {
    uint256 public sellPrice;
    uint256 public buyPrice;
    uint256 public minAmount;
    uint256 public soldToken;

    uint internal constant MIN_ETHER        = 1*1e16; // 0.01 ether
    uint internal constant EXCHANGE_RATE    = 10000;  // 1 eth = 10000 VALUE

    mapping (address =&gt; bool) public frozenAccount;

    /* This generates a public event on the blockchain that will notify clients */
    event FrozenFunds(address target, bool frozen);
    event LogWithdrawContractToken(address indexed owner, uint value);
    event LogFallbackTracer(address indexed owner, uint value);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function ValueToken (
        uint256 initialSupply,
        string tokenName,
        string tokenSymbol
    ) TokenERC20(initialSupply, tokenName, tokenSymbol) public {
        
    }

    /* Internal transfer, only can be called by this contract */
    function _transfer(address _from, address _to, uint _value) internal {
        require (_to != 0x0);                                 // Prevent transfer to 0x0 address. Use burn() instead
        require (balanceOf[_from] &gt;= _value);                 // Check if the sender has enough
        require (balanceOf[_to] + _value &gt;= balanceOf[_to]);  // Check for overflows
        require(!frozenAccount[_from]);                       // Check if sender is frozen
        require(!frozenAccount[_to]);                         // Check if recipient is frozen
        require(!isLockup(_from));
        require(!isLockup(_to));

        balanceOf[_from] = SafeMath.sub(balanceOf[_from], _value);   // Subtract from the sender
        balanceOf[_to] = SafeMath.add(balanceOf[_to], _value);       // Add the same to the recipient
        Transfer(_from, _to, _value);
    }

    /// @notice Create `mintedAmount` tokens and send it to `target`
    /// @param target Address to receive the tokens
    /// @param mintedAmount the amount of tokens it will receive
    function mintToken(address target, uint256 mintedAmount) onlyOwner public {
        balanceOf[target] = SafeMath.add(balanceOf[target], mintedAmount);
        totalSupply = SafeMath.add(totalSupply, mintedAmount);
        Transfer(0, this, mintedAmount);
        Transfer(this, target, mintedAmount);
    }

    /// @notice `freeze? Prevent | Allow` `target` from sending &amp; receiving tokens
    /// @param target Address to be frozen
    /// @param freeze either to freeze it or not
    function freezeAccount(address target, bool freeze) onlyOwner public {
        require(!isOwner(target));
        require(!frozenAccount[target]);

        frozenAccount[target] = freeze;
        FrozenFunds(target, freeze);
    }

    function withdrawContractToken(uint _value) onlyOwner public returns (bool success) {
        _transfer(this, msg.sender, _value);
        LogWithdrawContractToken(msg.sender, _value);
        return true;
    }
    
    function getContractBalanceOf() public constant returns(uint blance) {
        blance = balanceOf[this];
    }
    
    // payable
    function () payable public {
        require(MIN_ETHER &lt;= msg.value);
        uint amount = msg.value;
        uint token = amount.mul(EXCHANGE_RATE);
        require(token &gt; 0);
        _transfer(this, msg.sender, amount);
        LogFallbackTracer(msg.sender, amount);
    }
}