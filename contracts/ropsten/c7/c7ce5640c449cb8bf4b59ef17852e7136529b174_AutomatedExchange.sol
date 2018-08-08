pragma solidity ^0.4.18; // solhint-disable-line



// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20.md
// ----------------------------------------------------------------------------
contract ERC20Interface {
    function totalSupply() public constant returns (uint);
    function balanceOf(address tokenOwner) public constant returns (uint balance);
    function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
    function transfer(address to, uint tokens) public returns (bool success);
    function approve(address spender, uint tokens) public returns (bool success);
    function transferFrom(address from, address to, uint tokens) public returns (bool success);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}

contract ApproveAndCallFallBack {
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public;
}

contract AutomatedExchange is ApproveAndCallFallBack{

    uint256 PSN=100000000000000;
    uint256 PSNH=50000000000000;
    address creator;
    address vrfAddress=0x64F82571C326487cac31669F1e797EA0c9650879;
    ERC20Interface vrfcontract=ERC20Interface(vrfAddress);
    event BoughtToken(uint tokens,uint eth);
    event SoldToken(uint tokens,uint eth);
    function AutomatedExchange() public{
      creator=msg.sender;
    }
    function setAddress(address newaddr) public payable{
      require(msg.sender==creator);//only contract creator can set the address
      require(vrfAddress==0);//this can only be called once
      vrfAddress=newaddr;
    }
    //Tokens are sold by sending them to this contract with ApproveAndCall
    function receiveApproval(address from, uint256 tokens, address token, bytes data) public{
        //only allow this to be called from the token contract
        require(msg.sender==vrfAddress);
        uint256 tokenValue=calculateTokenSell(tokens);
        vrfcontract.transferFrom(from,this,tokens);
        from.transfer(tokenValue);
        emit SoldToken(tokens,tokenValue);
    }
    function buyTokens() public payable{
        uint256 tokensBought=calculateTokenBuy(msg.value,SafeMath.sub(this.balance,msg.value));
        vrfcontract.transfer(msg.sender,tokensBought);
        emit BoughtToken(tokensBought,msg.value);
    }
    //magic trade balancing algorithm
    function calculateTrade(uint256 rt,uint256 rs, uint256 bs) public view returns(uint256){
        //(PSN*bs)/(PSNH+((PSN*rs+PSNH*rt)/rt));
        return SafeMath.div(SafeMath.mul(PSN,bs),SafeMath.add(PSNH,SafeMath.div(SafeMath.add(SafeMath.mul(PSN,rs),SafeMath.mul(PSNH,rt)),rt)));
    }
    function calculateTokenSell(uint256 tokens) public view returns(uint256){
        return calculateTrade(tokens,vrfcontract.balanceOf(this),this.balance);
    }
    function calculateTokenBuy(uint256 eth,uint256 contractBalance) public view returns(uint256){
        return calculateTrade(eth,contractBalance,vrfcontract.balanceOf(this));
    }
    function calculateTokenBuySimple(uint256 eth) public view returns(uint256){
        return calculateTokenBuy(eth,this.balance);
    }

    //allow sending eth to the contract
    function () public payable {}

    function getBalance() public view returns(uint256){
        return this.balance;
    }
    function getTokenBalance() public view returns(uint256){
        return vrfcontract.balanceOf(this);
    }
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}

library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn&#39;t hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}