pragma solidity ^0.4.6;

//
// ==== DISCLAIMER ====
//
// ETHEREUM IS STILL AN EXPEREMENTAL TECHNOLOGY.
// ALTHOUGH THIS SMART CONTRACT CREATED WITH GREAT CARE AND IN HOPE TO BE USEFUL, NO GUARANTEES OF FLAWLES OPERATION CAN BE GIVEN. 
// ESPECIALLY SUBTILE BUGS, HACKER ATTACS OR MALFUNCTION OF UNDERLYING TECHNOLOGY CAN CAUSE AN UNINTENTIONAL BEHAVIOUR. 
// YOU ARE DEEPLY ENCORAGED TO STUDY THIS SMART CONTRACT CAREFULLY IN ORDER TO UNDERSTAND POSSIBLE EDGE CASES AND RISKS. 
// DON&#39;T USE THIS SMART CONTRACT IN CASE OF ANY SUBSTANTIONAL DOUBTS OR IF YOU DON&#39;T KNOW WHAT ARE YOU DOING.
//
// THIS SOFTWARE IS &quot;AS IS&quot; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY 
// AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
// OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// ====
//
//
// ==== PARANOIA NOTICE ==== 
// A careful reader will find here some unnecessary checks and excessive code consuming some extra valuable gas. It is intentionally. 
// Even contract should works without these parts, they make the code more secure in production as well for future refactoring.
// Additionally it shows more clearly what we have took care of.
// You are welcome to discuss that places.
// ====
//

/// @author ethernian
/// @notice report bugs to: <a href="/cdn-cgi/l/email-protection" class="__cf_email__" data-cfemail="bedccbd9cdfedbcad6dbccd0d7dfd090ddd1d3">[email&#160;protected]</a>
/// @title Presale Contract

contract Presale {

    string public constant VERSION = &quot;0.1.4-beta&quot;;

    /* ====== configuration START ====== */

    uint public constant PRESALE_START  = 3128000; /* approx. 05.02.2017 13:50 CET */
    uint public constant PRESALE_END    = 3128350; /* approx. 05.02.2017 15:00 CET */
    uint public constant WITHDRAWAL_END = 3128470; /* approx. 05.02.2017 15:30 CET */
    
    address public constant OWNER = 0x45d5426471D12b21C3326dD0cF96f6656F7d14b1;

    uint public constant MIN_TOTAL_AMOUNT_TO_RECEIVE_ETH = 1;
    uint public constant MAX_TOTAL_AMOUNT_TO_RECEIVE_ETH = 5;
    uint public constant MIN_ACCEPTED_AMOUNT_FINNEY = 1;

    /* ====== configuration END ====== */

    string[5] private stateNames = [&quot;BEFORE_START&quot;,  &quot;PRESALE_RUNNING&quot;, &quot;WITHDRAWAL_RUNNING&quot;, &quot;REFUND_RUNNING&quot;, &quot;CLOSED&quot; ];
    enum State { BEFORE_START,  PRESALE_RUNNING, WITHDRAWAL_RUNNING, REFUND_RUNNING, CLOSED }

    uint public total_received_amount;
    mapping (address =&gt; uint) public balances;

    uint private constant MIN_TOTAL_AMOUNT_TO_RECEIVE = MIN_TOTAL_AMOUNT_TO_RECEIVE_ETH * 1 ether;
    uint private constant MAX_TOTAL_AMOUNT_TO_RECEIVE = MAX_TOTAL_AMOUNT_TO_RECEIVE_ETH * 1 ether;
    uint private constant MIN_ACCEPTED_AMOUNT = MIN_ACCEPTED_AMOUNT_FINNEY * 1 finney;
    bool public isAborted = false;


    //constructor
    function Presale () validSetupOnly() { }

    //
    // ======= interface methods =======
    //

    //accept payments here
    function ()
    payable
    noReentrancy
    {
        State state = currentState();
        if (state == State.PRESALE_RUNNING) {
            receiveFunds();
        } else if (state == State.REFUND_RUNNING) {
            // any entring call in Refund Phase will cause full refund
            sendRefund();
        } else {
            throw;
        }
    }

    function refund() external
    inState(State.REFUND_RUNNING)
    noReentrancy
    {
        sendRefund();
    }


    function withdrawFunds() external
    inState(State.WITHDRAWAL_RUNNING)
    onlyOwner
    noReentrancy
    {
        // transfer funds to owner if any
        if (!OWNER.send(this.balance)) throw;
    }

    function abort() external
    inStateBefore(State.REFUND_RUNNING)
    onlyOwner
    {
        isAborted = true;
    }

    //displays current contract state in human readable form
    function state()  external constant
    returns (string)
    {
        return stateNames[ uint(currentState()) ];
    }


    //
    // ======= implementation methods =======
    //

    function sendRefund() private tokenHoldersOnly {
        // load balance to refund plus amount currently sent
        var amount_to_refund = balances[msg.sender] + msg.value;
        // reset balance
        balances[msg.sender] = 0;
        // send refund back to sender
        if (!msg.sender.send(amount_to_refund)) throw;
    }


    function receiveFunds() private notTooSmallAmountOnly {
      // no overflow is possible here: nobody have soo much money to spend.
      if (total_received_amount + msg.value &gt; MAX_TOTAL_AMOUNT_TO_RECEIVE) {
          // accept amount only and return change
          var change_to_return = total_received_amount + msg.value - MAX_TOTAL_AMOUNT_TO_RECEIVE;
          if (!msg.sender.send(change_to_return)) throw;

          var acceptable_remainder = MAX_TOTAL_AMOUNT_TO_RECEIVE - total_received_amount;
          balances[msg.sender] += acceptable_remainder;
          total_received_amount += acceptable_remainder;
      } else {
          // accept full amount
          balances[msg.sender] += msg.value;
          total_received_amount += msg.value;
      }
    }


    function currentState() private constant returns (State) {
        if (isAborted) {
            return this.balance &gt; 0 
                   ? State.REFUND_RUNNING 
                   : State.CLOSED;
        } else if (block.number &lt; PRESALE_START) {
            return State.BEFORE_START;
        } else if (block.number &lt;= PRESALE_END &amp;&amp; total_received_amount &lt; MAX_TOTAL_AMOUNT_TO_RECEIVE) {
            return State.PRESALE_RUNNING;
        } else if (this.balance == 0) {
            return State.CLOSED;
        } else if (block.number &lt;= WITHDRAWAL_END &amp;&amp; total_received_amount &gt;= MIN_TOTAL_AMOUNT_TO_RECEIVE) {
            return State.WITHDRAWAL_RUNNING;
        } else {
            return State.REFUND_RUNNING;
        } 
    }

    //
    // ============ modifiers ============
    //

    //fails if state dosn&#39;t match
    modifier inState(State state) {
        if (state != currentState()) throw;
        _;
    }

    //fails if the current state is not before than the given one.
    modifier inStateBefore(State state) {
        if (currentState() &gt;= state) throw;
        _;
    }

    //fails if something in setup is looking weird
    modifier validSetupOnly() {
        if ( OWNER == 0x0 
            || PRESALE_START == 0 
            || PRESALE_END == 0 
            || WITHDRAWAL_END ==0
            || PRESALE_START &lt;= block.number
            || PRESALE_START &gt;= PRESALE_END
            || PRESALE_END   &gt;= WITHDRAWAL_END
            || MIN_TOTAL_AMOUNT_TO_RECEIVE &gt; MAX_TOTAL_AMOUNT_TO_RECEIVE )
                throw;
        _;
    }


    //accepts calls from owner only
    modifier onlyOwner(){
        if (msg.sender != OWNER)  throw;
        _;
    }


    //accepts calls from token holders only
    modifier tokenHoldersOnly(){
        if (balances[msg.sender] == 0) throw;
        _;
    }


    // don`t accept transactions with value less than allowed minimum
    modifier notTooSmallAmountOnly(){	
        if (msg.value &lt; MIN_ACCEPTED_AMOUNT) throw;
        _;
    }


    //prevents reentrancy attacs
    bool private locked = false;
    modifier noReentrancy() {
        if (locked) throw;
        locked = true;
        _;
        locked = false;
    }
}//contract