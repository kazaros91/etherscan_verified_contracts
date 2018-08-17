pragma solidity ^0.4.24;
/* CKBC
// Cinnamomum Kanehirae BlockChain (CKBC)
// ERC20 Contract with Timelock capabilities
// The big intricate timelock mechanisms out here
// ---
// ---
*/

/* an owner is required */
contract Owned {
    address public owner;

    function Owned() public {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function setOwner(address _owner) onlyOwner public {
        owner = _owner;
    }
}

/* SafeMath implementation to guard against overflows */
contract SafeMath {
    function add(uint256 _a, uint256 _b) internal pure returns (uint256) {
        uint256 c = _a + _b;
        assert(c &gt;= _a); // checks for overflow
        return c;
    }

    function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {
        assert(_a &gt;= _b); // guard against overflow
        return _a - _b;
    }

    function mul(uint256 _a, uint256 _b) internal pure returns (uint256) {
        uint256 c = _a * _b;
        assert(_a == 0 || c / _a == _b); // checks for overflow
        return c;
    }
}

/* The main contract for the timelock capable ERC20 token */
contract Token is SafeMath, Owned {
    uint256 constant DAY_IN_SECONDS = 86400;
    string public constant standard = &quot;0.777&quot;;
    string public name = &quot;&quot;;
    string public symbol = &quot;&quot;;
    uint8 public decimals = 0;
    uint256 public totalSupply = 0;
    mapping (address =&gt; uint256) public balanceP;
    mapping (address =&gt; mapping (address =&gt; uint256)) public allowance;

    mapping (address =&gt; uint256[]) public lockTime;
    mapping (address =&gt; uint256[]) public lockValue;
    mapping (address =&gt; uint256) public lockNum;
    mapping (address =&gt; bool) public locker;
    uint256 public later = 0;
    uint256 public earlier = 0;


    /* standard ERC20 events */
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);

    /* custom lock-related events */
    event TransferredLocked(address indexed _from, address indexed _to, uint256 _time, uint256 _value);
    event TokenUnlocked(address indexed _address, uint256 _value);

    /* ERC20 constructor */
    function Token(string _name, string _symbol, uint8 _decimals, uint256 _totalSupply) public {
        require(bytes(_name).length &gt; 0 &amp;&amp; bytes(_symbol).length &gt; 0);

        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        totalSupply = _totalSupply;

        balanceP[msg.sender] = _totalSupply;

    }

    /* don&#39;t allow zero address */
    modifier validAddress(address _address) {
        require(_address != 0x0);
        _;
    }

    /* owner may add &amp; remove optional locker contract */
    function addLocker(address _address) public validAddress(_address) onlyOwner {
        locker[_address] = true;
    }

    function removeLocker(address _address) public validAddress(_address) onlyOwner {
        locker[_address] = false;
    }

    /* owner may fast-forward or delay ALL timelocks */
    function setUnlockEarlier(uint256 _earlier) public onlyOwner {
        earlier = add(earlier, _earlier);
    }

    function setUnlockLater(uint256 _later) public onlyOwner {
        later = add(later, _later);
    }

    /* shows unlocked balance */
    function balanceUnlocked(address _address) public view returns (uint256 _balance) {
        _balance = balanceP[_address];
        uint256 i = 0;
        while (i &lt; lockNum[_address]) {
            if (add(now, earlier) &gt; add(lockTime[_address][i], later)) _balance = add(_balance, lockValue[_address][i]);
            i++;
        }
        return _balance;
    }

    /* shows locked balance */
    function balanceLocked(address _address) public view returns (uint256 _balance) {
        _balance = 0;
        uint256 i = 0;
        while (i &lt; lockNum[_address]) {
            if (add(now, earlier) &lt; add(lockTime[_address][i], later)) _balance = add(_balance, lockValue[_address][i]);
            i++;
        }
        return  _balance;
    }

    /* standard ERC20 compatible balance accessor */
    function balanceOf(address _address) public view returns (uint256 _balance) {
        _balance = balanceP[_address];
        uint256 i = 0;
        while (i &lt; lockNum[_address]) {
            _balance = add(_balance, lockValue[_address][i]);
            i++;
        }
        return _balance;
    }

    /* show the timelock periods and locked values */
    function showTime(address _address) public view validAddress(_address) returns (uint256[] _time) {
        uint i = 0;
        uint256[] memory tempLockTime = new uint256[](lockNum[_address]);
        while (i &lt; lockNum[_address]) {
            tempLockTime[i] = sub(add(lockTime[_address][i], later), earlier);
            i++;
        }
        return tempLockTime;
    }

    function showValue(address _address) public view validAddress(_address) returns (uint256[] _value) {
        return lockValue[_address];
    }

    /* calculates and handles the timelocks before related operations */
    function calcUnlock(address _address) private {
        uint256 i = 0;
        uint256 j = 0;
        uint256[] memory currentLockTime;
        uint256[] memory currentLockValue;
        uint256[] memory newLockTime = new uint256[](lockNum[_address]);
        uint256[] memory newLockValue = new uint256[](lockNum[_address]);
        currentLockTime = lockTime[_address];
        currentLockValue = lockValue[_address];
        while (i &lt; lockNum[_address]) {
            if (add(now, earlier) &gt; add(currentLockTime[i], later)) {
                balanceP[_address] = add(balanceP[_address], currentLockValue[i]);

                /* emit timelock expiration event */
                emit TokenUnlocked(_address, currentLockValue[i]);
            } else {
                newLockTime[j] = currentLockTime[i];
                newLockValue[j] = currentLockValue[i];
                j++;
            }
            i++;
        }
        uint256[] memory trimLockTime = new uint256[](j);
        uint256[] memory trimLockValue = new uint256[](j);
        i = 0;
        while (i &lt; j) {
            trimLockTime[i] = newLockTime[i];
            trimLockValue[i] = newLockValue[i];
            i++;
        }
        lockTime[_address] = trimLockTime;
        lockValue[_address] = trimLockValue;
        lockNum[_address] = j;
    }

    /* ERC20 compliant transfer method */
    function transfer(address _to, uint256 _value) public validAddress(_to) returns (bool success) {
        if (lockNum[msg.sender] &gt; 0) calcUnlock(msg.sender);
        if (balanceP[msg.sender] &gt;= _value &amp;&amp; _value &gt; 0) {
            balanceP[msg.sender] = sub(balanceP[msg.sender], _value);
            balanceP[_to] = add(balanceP[_to], _value);
            emit Transfer(msg.sender, _to, _value);
            return true;
        }
        else {
            return false;
        }
    }

    /* custom timelocked transfer method */
    function transferLocked(address _to, uint256[] _time, uint256[] _value) public validAddress(_to) returns (bool success) {
        require(_value.length == _time.length);

        if (lockNum[msg.sender] &gt; 0) calcUnlock(msg.sender);
        uint256 i = 0;
        uint256 totalValue = 0;
        while (i &lt; _value.length) {
            totalValue = add(totalValue, _value[i]);
            i++;
        }
        if (balanceP[msg.sender] &gt;= totalValue &amp;&amp; totalValue &gt; 0) {
            i = 0;
            while (i &lt; _time.length) {
                balanceP[msg.sender] = sub(balanceP[msg.sender], _value[i]);
                lockTime[_to].length = lockNum[_to]+1;
                lockValue[_to].length = lockNum[_to]+1;
                lockTime[_to][lockNum[_to]] = add(now, _time[i]);
                lockValue[_to][lockNum[_to]] = _value[i];

                /* emit custom timelock event */
                emit TransferredLocked(msg.sender, _to, lockTime[_to][lockNum[_to]], lockValue[_to][lockNum[_to]]);

                /* emit standard transfer event */
                emit Transfer(msg.sender, _to, lockValue[_to][lockNum[_to]]);
                lockNum[_to]++;
                i++;
            }
            return true;
        }
        else {
            return false;
        }
    }

    /* custom timelocked method */
    function transferLockedFrom(address _from, address _to, uint256[] _time, uint256[] _value) public
	    validAddress(_from) validAddress(_to) returns (bool success) {
        require(locker[msg.sender]);
        require(_value.length == _time.length);

        if (lockNum[_from] &gt; 0) calcUnlock(_from);
        uint256 i = 0;
        uint256 totalValue = 0;
        while (i &lt; _value.length) {
            totalValue = add(totalValue, _value[i]);
            i++;
        }
        if (balanceP[_from] &gt;= totalValue &amp;&amp; totalValue &gt; 0) {
            i = 0;
            while (i &lt; _time.length) {
                balanceP[_from] = sub(balanceP[_from], _value[i]);
                lockTime[_to].length = lockNum[_to]+1;
                lockValue[_to].length = lockNum[_to]+1;
                lockTime[_to][lockNum[_to]] = add(now, _time[i]);
                lockValue[_to][lockNum[_to]] = _value[i];

                /* emit custom timelock event */
                emit TransferredLocked(_from, _to, lockTime[_to][lockNum[_to]], lockValue[_to][lockNum[_to]]);

                /* emit standard transfer event */
                emit Transfer(_from, _to, lockValue[_to][lockNum[_to]]);
                lockNum[_to]++;
                i++;
            }
            return true;
        }
        else {
            return false;
        }
    }

    /* standard ERC20 compliant transferFrom method */
    function transferFrom(address _from, address _to, uint256 _value) public validAddress(_from) validAddress(_to) returns (bool success) {
        if (lockNum[_from] &gt; 0) calcUnlock(_from);
        if (balanceP[_from] &gt;= _value &amp;&amp; _value &gt; 0) {
            allowance[_from][msg.sender] = sub(allowance[_from][msg.sender], _value);
            balanceP[_from] = sub(balanceP[_from], _value);
            balanceP[_to] = add(balanceP[_to], _value);
            emit Transfer(_from, _to, _value);
            return true;
        }
        else {
            return false;
        }
    }

    /* standard ERC20 compliant approve method */
    function approve(address _spender, uint256 _value) public validAddress(_spender) returns (bool success) {
        require(_value == 0 || allowance[msg.sender][_spender] == 0);

        if (lockNum[msg.sender] &gt; 0) calcUnlock(msg.sender);
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    /* safety method against ether transfer */
    function () public payable {
        revert();
    }

}