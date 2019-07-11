pragma solidity ^0.4.23;

/*
 * Arcadia Escrow Contract - heavily borrowed from localethereum.com
 */
contract ArcadiaEscrows {
    address public arbitrator;
    address public owner;
    uint32 public requestCancellationMinimumTime;
    uint256 public arcadiaAvailFees;

    event Created(uint16 tradeHash);
    event SellerCancelDisabled(uint16 tradeHash);
    event SellerRequestedCancel(uint16 tradeHash);
    event CancelledBySeller(uint16 tradeHash);
    event CancelledByBuyer(uint16 tradeHash);
    event Released(uint16 tradeHash);
    event ReleasedDebug(string msg);
    event TransferDebug(string msg, uint256 val);
    event DisputeResolved(uint16 tradeHash);

    /* Trade Structure includes:
     * exists - true if a valid Trade
     * seller - the address of seller
     * buyer - the address of buyer
     * value - the value of the trade in wei
     * fee - the Arcadia fee that is withheld for finalized or disputed trades
     * sellerCanCancelAfter - the timestamp after which the seller can cancel, with the 
     *   following special values:
     *    0 - seller cannot cancel: buyer has marked the trade paid or a dispute is active
     *    1 - seller can request cancelation which will take effect after requestCancellationMinimumTime
     */
     struct Trade {
        bool     exists;
        address  seller;
        address  buyer;
        uint256  value;
        uint16   fee;
        uint32   sellerCanCancelAfter;
    }

    /* Active Trade Mapping, key is a hash of the tradeID, seller an buyer */
    mapping (uint16 => Trade) public trades;

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only owner can call this.");
        _;
    }

    modifier onlyArbitrator() {
        require(
            msg.sender == arbitrator,
            "Only arbitrator can call this.");
        _;
    }

    constructor() public {
        owner = msg.sender;
        arbitrator = msg.sender;
        requestCancellationMinimumTime = 2 hours;
    }

    /*
     * Given the tradeID, seller and buyer, retrieve the Trade structure and hash.
     */
    function getTradeAndHash (uint16 tradeID, address seller, address buyer) view private returns (Trade, uint16) {
        //bytes32 tradeHash = keccak256(tradeID, seller, buyer);
        uint16 tradeHash = tradeID;
        return (trades[tradeHash], tradeHash);
    }

    uint16 constant GAS = 40000;

    /*
     * Creates a new Trade. 
     * Input Parameters:
     *  - tradeID: Unique trade identifier generated by Arcadia Platform
     *  - seller: Address of seller
     *  - buyer: Address of buyer
     *  - value: The amount (in wei) being traded and to be held in escrow
     *  - fee: The Arcadia fee in 1/10000-ths
     *  - paymentWindow: The time in seconds that the buyer has to mark the trade paid. 
     *    Before this time seller cannot cancel. After this time, seller can cancel.
     *    If 0 or 1 - set value to 1 that has special meaning: the seller can ask
     *                for cancelation at any time and can cancel after 
     */
    function createTrade (
      uint16 tradeID, 
      address seller, address buyer, 
      uint256 value, uint16 fee, uint32 paymentWindow
    ) payable external {
        require(msg.sender == seller);
        //bytes32 tradeHash = keccak256(tradeID, seller, buyer);
        uint16 tradeHash = tradeID;
        require(!trades[tradeHash].exists);
        /* Make sure ether is sent according to the Trade terms */
        require(msg.value == value && msg.value > 0);
        uint32 sellerCanCancelAfter = paymentWindow == 0 ? 1 : uint32(block.timestamp) + paymentWindow;
        trades[tradeHash] = Trade(true, seller, buyer, value, fee, sellerCanCancelAfter);
        emit Created(tradeHash);
    }

    /*
     * Release the funds from escrow to buyer
     */
    function releaseFunds (uint16 tradeID, address seller, address buyer) 
      external returns (bool) {
        require(msg.sender == seller);
        uint16 tradeHash;
        Trade memory trade;
        (trade, tradeHash) = getTradeAndHash(tradeID, seller, buyer);
        if (!trade.exists) return false;

        uint128 gasFees = GAS * uint128(tx.gasprice);
        delete trades[tradeHash];
        emit Released(tradeHash);
        transferMinusFees(buyer, trade.value, gasFees, trade.fee);
        return true;
    }

    /*
     * Buyer stops the seller from cancelling the trade.
     * Used to mark the trade as paid, or if the buyer has a dispute.
     */
    function disableSellerCancel (uint16 tradeID, address seller, address buyer) 
      external returns (bool) {
        require(msg.sender == buyer);
        uint16 tradeHash;
        Trade memory trade;
        (trade, tradeHash) = getTradeAndHash(tradeID, seller, buyer);
        if (!trade.exists) return false;
        if(trade.sellerCanCancelAfter == 0) return false;
        trades[tradeHash].sellerCanCancelAfter = 0;
        emit SellerCancelDisabled(tradeHash);
        return true;
    }

    /*
     * Buyer cancels the trade, the ether is returned to the seller.
     */
    function buyerCancel (uint16 tradeID, address seller, address buyer)
      external returns (bool) {
        require(msg.sender == buyer);
        uint16 tradeHash;
        Trade memory trade;
        (trade, tradeHash) = getTradeAndHash(tradeID, seller, buyer);
        if (!trade.exists) return false;
        delete trades[tradeHash];
        emit CancelledByBuyer(tradeHash);
        uint128 gasFees = GAS * uint128(tx.gasprice);
        transferMinusFees(seller, trade.value, gasFees, 0);
        return true;
    }

    /*
     * Seller cancels the trade and recovers the ether. 
     * Can only be called if the payment window has expired.
     */
    function sellerCancel (uint16 tradeID, address seller, address buyer)
      external returns (bool) {
        require(msg.sender == seller);
        uint16 tradeHash;
        Trade memory trade;
        (trade, tradeHash) = getTradeAndHash(tradeID, seller, buyer);
        if (!trade.exists) return false;
        if(trade.sellerCanCancelAfter <= 1 || trade.sellerCanCancelAfter > block.timestamp) return false;
        delete trades[tradeHash];
        emit CancelledBySeller(tradeHash);
        uint128 gasFees = GAS * uint128(tx.gasprice);
        transferMinusFees(seller, trade.value, gasFees, 0);
        return true;
    }

    /*
     * Seller requests cancelation. Can only be called for trades without expiry of 
     * payment window (sellerCanCancelAfter == 1)
     */
    function sellerRequestCancel (uint16 tradeID, address seller, address buyer) 
      external returns (bool) {
        require(msg.sender == seller);
        uint16 tradeHash;
        Trade memory trade;
        (trade, tradeHash) = getTradeAndHash(tradeID, seller, buyer);
        if (!trade.exists) return false;
        if(trade.sellerCanCancelAfter != 1) return false;
        trades[tradeHash].sellerCanCancelAfter = uint32(block.timestamp) + requestCancellationMinimumTime;
        emit SellerRequestedCancel(tradeHash);
        return true;
    }

    /*
     * Arbitrator resolves a dispute by returning funds to buyer and/ or seller.
     * The buyerPercent parameter indicates how the split happens.
     */
    function resolveDispute (uint16 tradeID, address seller, address buyer, uint8 buyerPercent)
      external onlyArbitrator {
        uint16 tradeHash;
        Trade memory trade;
        (trade, tradeHash) = getTradeAndHash(tradeID, seller, buyer);
        require(trade.exists);
        require(buyerPercent <= 100);

        uint256 totalFees =  GAS * uint128(tx.gasprice);
        uint256 value = trade.value;
        require(value - totalFees <= value);
        arcadiaAvailFees += totalFees;

        delete trades[tradeHash];
        emit DisputeResolved(tradeHash);
        buyer.transfer((value - totalFees) * buyerPercent / 100);
        seller.transfer((value - totalFees) * (100 - buyerPercent) / 100);
    }

    /*
     * Helper function for fund transfers. "Moves" the fee into arcadiaAvailFees,
     * transfers the remainder of value to the address specified in "to".
     */
    function transferMinusFees(address to, uint256 value, uint128 gasFees, uint16 fee) 
      private {
        //uint256 totalFees = (value * fee / 10000) + gasFees;
        uint256 totalFees = (value * fee / 10000);
        if(value - totalFees > value) {
            emit TransferDebug("Not enough funds to cover fees", value - totalFees);
            return; 
        }
        arcadiaAvailFees += (value * fee / 10000);
        emit TransferDebug("Attempt transfer of:", value - totalFees);
        to.transfer(value - totalFees);
    }

    /*
     * Send some of the fees collected by contract to owner
     */
    function withdrawFees(address to, uint256 value) 
      onlyOwner external {
        require(value <= arcadiaAvailFees);
        arcadiaAvailFees -= value;
        to.transfer(value);
    }

    /*
     * Changes the arbitrator.
     */
    function setArbitrator(address newArbitrator) 
      onlyOwner external {
        arbitrator = newArbitrator;
    }

    /*
     * Changes the owner.
     */
    function setOwner(address newOwner) 
      onlyOwner external {
        owner = newOwner;
    }

    /*
     * Changes the time window for payment. When expires the seller can cancel the trade.
     */
    function setRequestCancellationMinimumTime(uint32 newMinimumTime) 
      onlyOwner external {
        requestCancellationMinimumTime = newMinimumTime;
    }
}