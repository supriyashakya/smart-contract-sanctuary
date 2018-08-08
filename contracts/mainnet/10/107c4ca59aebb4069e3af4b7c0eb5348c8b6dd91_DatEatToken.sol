pragma solidity ^0.4.23;

/**
 * @title ERC20 interface
 * @dev see https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 {
    function totalSupply() public view returns (uint256);
    function balanceOf(address who) public view returns (uint256);
    function transfer(address to, uint256 value) public returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);    

    function allowance(address owner, address spender)
        public view returns (uint256);

    function transferFrom(address from, address to, uint256 value)
        public returns (bool);

    function approve(address spender, uint256 value) public returns (bool);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        assert(c / a == b);
        return c;
    }

    /**
    * @dev Integer division of two numbers, truncating the quotient.
    */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        // uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn&#39;t hold
        return a / b;
    }

    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        assert(c >= a);
        return c;
    }
}

/**
 * @title Standard ERC20 token
 *
 * @dev Implementation of the basic standard token.
 * @dev https://github.com/ethereum/EIPs/issues/20
 * @dev Based on code by FirstBlood: https://github.com/Firstbloodio/token/blob/master/smart_contract/FirstBloodToken.sol
 */
contract DatEatToken is ERC20 {
    using SafeMath for uint256;

    mapping(address => uint256) balances;
    mapping (address => mapping (address => uint256)) internal allowed;
    mapping (address => uint256) public freezedAccounts;

    uint256 totalSupply_;
    string public constant name = &quot;DatEatToken&quot;; // solium-disable-line uppercase
    string public constant symbol = &quot;DTE&quot;; // solium-disable-line uppercase
    uint8 public constant decimals = 18; // solium-disable-line uppercase

    uint256 constant icoSupply = 200000000 * (10 ** uint256(decimals));
    uint256 constant founderSupply = 60000000 * (10 ** uint256(decimals));
    uint256 constant defoundSupply = 50000000 * (10 ** uint256(decimals));
    uint256 constant year1Supply = 75000000 * (10 ** uint256(decimals));
    uint256 constant year2Supply = 75000000 * (10 ** uint256(decimals));
    uint256 constant bountyAndBonusSupply = 40000000 * (10 ** uint256(decimals));

    uint256 constant founderFrozenUntil = 1559347200; // 2019/06/01
    uint256 constant defoundFrozenUntil = 1546300800; // 2019/01/01
    uint256 constant year1FrozenUntil = 1559347200; // 2019/06/01
    uint256 constant year2FrozenUntil = 1590969600; // 2020/06/01

    event Burn(address indexed burner, uint256 value);

    constructor(
        address _icoAddress, 
        address _founderAddress,
        address _defoundAddress, 
        address _year1Address, 
        address _year2Address, 
        address _bountyAndBonusAddress
    ) public {
        totalSupply_ = 500000000 * (10 ** uint256(decimals));
        balances[_icoAddress] = icoSupply;
        balances[_bountyAndBonusAddress] = bountyAndBonusSupply;
        emit Transfer(address(0), _icoAddress, icoSupply);
        emit Transfer(address(0), _bountyAndBonusAddress, bountyAndBonusSupply);

        _setFreezedBalance(_founderAddress, founderSupply, founderFrozenUntil);
        _setFreezedBalance(_defoundAddress, defoundSupply, defoundFrozenUntil);
        _setFreezedBalance(_year1Address, year1Supply, year1FrozenUntil);
        _setFreezedBalance(_year2Address, year2Supply, year2FrozenUntil);
    }

    /**
    * @dev total number of tokens in existence
    */
    function totalSupply() public view returns (uint256) {
        return totalSupply_;
    }

    /**
    * @dev transfer token for a specified address
    * @param _to The address to transfer to.
    * @param _value The amount to be transferred.
    */
    function transfer(address _to, uint256 _value) public returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);
        // solium-disable-next-line security/no-block-members
        require(freezedAccounts[msg.sender] == 0 || freezedAccounts[msg.sender] < block.timestamp);
        // solium-disable-next-line security/no-block-members
        require(freezedAccounts[_to] == 0 || freezedAccounts[_to] < block.timestamp);

        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
    * @dev batchTransfer token for a specified addresses
    * @param _tos The addresses to transfer to.
    * @param _values The amounts to be transferred.
    */
    function batchTransfer(address[] _tos, uint256[] _values) public returns (bool) {
        require(_tos.length == _values.length);
        uint256 arrayLength = _tos.length;
        for(uint256 i = 0; i < arrayLength; i++) {
            transfer(_tos[i], _values[i]);
        }
        return true;
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
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);
        // solium-disable-next-line security/no-block-members
        require(freezedAccounts[_from] == 0 || freezedAccounts[_from] < block.timestamp);
        // solium-disable-next-line security/no-block-members
        require(freezedAccounts[_to] == 0 || freezedAccounts[_to] < block.timestamp);

        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
    * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
    *
    * Beware that changing an allowance with this method brings the risk that someone may use both the old
    * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
    * race condition is to first reduce the spender&#39;s allowance to 0 and set the desired value afterwards:
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
    * @dev Increase the amount of tokens that an owner allowed to a spender.
    *
    * approve should be called when allowed[_spender] == 0. To increment
    * allowed value is better to use this function to avoid 2 calls (and wait until
    * the first transaction is mined)
    * From MonolithDAO Token.sol
    * @param _spender The address which will spend the funds.
    * @param _addedValue The amount of tokens to increase the allowance by.
    */
    function increaseApproval(
        address _spender,
        uint _addedValue
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
    *
    * approve should be called when allowed[_spender] == 0. To decrement
    * allowed value is better to use this function to avoid 2 calls (and wait until
    * the first transaction is mined)
    * From MonolithDAO Token.sol
    * @param _spender The address which will spend the funds.
    * @param _subtractedValue The amount of tokens to decrease the allowance by.
    */
    function decreaseApproval(
        address _spender,
        uint _subtractedValue
    )
        public
        returns (bool)
    {
        uint oldValue = allowed[msg.sender][_spender];
        if (_subtractedValue > oldValue) {
            allowed[msg.sender][_spender] = 0;
        } else {
            allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
        }
        emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
        return true;
    }

    /**
     * Set balance and freeze time for address
     */
    function _setFreezedBalance(address _owner, uint256 _amount, uint _lockedUntil) internal {
        require(_owner != address(0));
        require(balances[_owner] == 0);
        freezedAccounts[_owner] = _lockedUntil;
        balances[_owner] = _amount;     
    }

    /**
    * @dev Burns a specific amount of tokens.
    * @param _value The amount of token to be burned.
    */
    function burn(uint256 _value) public {
        _burn(msg.sender, _value);
    }

    function _burn(address _who, uint256 _value) internal {
        require(_value <= balances[_who]);
        // no need to require value <= totalSupply, since that would imply the
        // sender&#39;s balance is greater than the totalSupply, which *should* be an assertion failure

        balances[_who] = balances[_who].sub(_value);
        totalSupply_ = totalSupply_.sub(_value);
        emit Burn(_who, _value);
        emit Transfer(_who, address(0), _value);
    }

    // do not send eth to this contract
    function () external payable {
        revert();
    }
}