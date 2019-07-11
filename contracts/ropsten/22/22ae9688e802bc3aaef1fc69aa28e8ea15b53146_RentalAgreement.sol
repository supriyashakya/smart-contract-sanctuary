pragma solidity ^0.4.25; library SafeMath { function mul(uint256 a, uint256 b) internal pure returns (uint256) { uint256 c = a * b; assert(a == 0 || c / a == b); return c; } function div(uint256 a, uint256 b) internal pure returns (uint256) { uint256 c = a / b; return c; } function sub(uint256 a, uint256 b) internal pure returns (uint256) { assert(b <= a); return a - b; } function add(uint256 a, uint256 b) internal pure returns (uint256) { uint256 c = a + b; assert(c >= a && c >= b); return c; } } interface notifier { function approved(address user) external; function deposit(address user, uint256 amount) external; function withdraw(address user, uint256 amount) external; function rentModified(address user, uint256 amount) external; function ticket(address user, bool ticketOpen) external; function dispute(address user, bool ongGoing) external; function admin(address user) external returns (bool); } contract RentalAgreement { using SafeMath for uint256; /* CLAUSES VARIABLES */ struct Clauses{ General general; PropertyDetails property; Parties parties; Terms terms; FinalDetails finalDetails; } /* GENERAL VARIABLES */ struct General{ Property property; LeaseDetails leaseDetails; } struct Property{ uint256 Ptype; } struct LeaseDetails{ uint256 dateLeaseStarts; } /* PROPERTY DETAILS VARIABLES */ struct PropertyDetails{ Details details; } struct Details{ uint256 selectedAccessToParking; } /* PARTIES VARIABLES */ struct Parties{ Tenant tenant; Landlord landlord; uint256 selectedOccupantsOptions; } struct Tenant{ address wallet; } struct Landlord{ address wallet; } /* TERMS VARIABLES */ struct Terms{ Rent rent; RentIncrease rentIncrease; SecurityDeposit securityDeposit; UseOfProperty useOfProperty; LatePayments latePayments; UtilitiesDetails utilitiesDetails; } struct Rent{ uint256 amount; uint256 paymentDateDay; } struct RentIncrease{ uint256 selectedIncrementNotice; uint256 daysNoticeBeforeIncreasingRent; } struct SecurityDeposit{ uint256 amount; } struct UseOfProperty{ uint256 selectedPetsAllowance; uint256 selectedSmokingAllowance; } struct LatePayments{ uint256 selectedLatePayment; uint256 amount; uint256 percentage; } struct UtilitiesDetails{ uint256 selectedUtilitiesDetails; uint256[] utilities; } /*FINAL DETAILS VARIABLES*/ struct FinalDetails{ DisputeResolution disputeResolution; AdditionalClauses additionalClauses; } struct DisputeResolution{ uint256 selectedDisputeResolution; uint256 selectedDisputeResolutionCost; } struct AdditionalClauses{ uint256 selectedAdditionalClause; } struct AmountInfo{ uint256 amount; uint256 timestamp; uint256 blockNumber; } struct TicketInfo{ bool open; uint256 timestamp; uint256 blockNumber; } struct DisputeInfo{ bool onGoing; address startedBy; uint256 timestamp; uint256 blockNumber; } notifier public Notifier; Clauses public clauses; bool public agreementApproved; AmountInfo public depositInfo; AmountInfo public withdrawalInfo; AmountInfo public rentModificationInfo; TicketInfo public ticketInfo; DisputeInfo public disputeInfo; uint256 public lockedAmount; uint256 public availableAmount; event Approved(address user, uint256 timestamp); event Deposit(address user, uint256 amount, uint256 timestamp); event Withdraw(address user, uint256 amount, uint256 timestamp); event RentModified(address user, uint256 amount, uint256 timestamp); event Ticket(address user, bool open, uint256 timestamp); event Dispute(address user, bool onGoing, uint256 timestamp); constructor() public { /* RENTAL AGREEMENT CLAUSES START HERE */ /* GENERAL CLAUSES */ clauses.general.property.Ptype = 2; clauses.general.leaseDetails.dateLeaseStarts = 1543297365; /* PROPERTY CLAUSES */ clauses.property.details.selectedAccessToParking = 2; /* PARTIES CLAUSES */ clauses.parties.tenant.wallet = 0xca88bc68e87b080d82a13d531b273d15549bf2c5; clauses.parties.landlord.wallet = 0xf4b5af556185a9fb62ce96805424a11be5b373ff; clauses.parties.selectedOccupantsOptions = 2; /* TERMS CLAUSES */ clauses.terms.rent.amount = 2500; clauses.terms.rent.paymentDateDay = 2; clauses.terms.rentIncrease.selectedIncrementNotice = 2; clauses.terms.rentIncrease.daysNoticeBeforeIncreasingRent = 0; clauses.terms.securityDeposit.amount = 2350; clauses.terms.useOfProperty.selectedPetsAllowance = 2; clauses.terms.useOfProperty.selectedSmokingAllowance = 2; clauses.terms.latePayments.selectedLatePayment = 4; clauses.terms.latePayments.amount = 300; clauses.terms.latePayments.percentage = 0; clauses.terms.utilitiesDetails.selectedUtilitiesDetails = 3; clauses.terms.utilitiesDetails.utilities = [1,2,1,2,1,2,1,2,1]; /*FINAL DETAILS CLAUSES*/ clauses.finalDetails.disputeResolution.selectedDisputeResolution = 4; clauses.finalDetails.disputeResolution.selectedDisputeResolutionCost = 1; clauses.finalDetails.additionalClauses.selectedAdditionalClause = 2; require(msg.sender == clauses.parties.landlord.wallet, &#39;You are not the Landlord&#39;); Notifier = notifier(0x561A407e8894c746d881eBf25a6033d24fd694aF); /*Event notifier*/ rentModificationInfo.amount = clauses.terms.rent.amount; } /*Tenant approves this this agreement*/ function approveAgreement() public { require(msg.sender == clauses.parties.tenant.wallet && !agreementApproved, "You are not not the Tenant"); agreementApproved = true; Notifier.approved(msg.sender); emit Approved(msg.sender, now); } /*The smart contract won&#39;t process any action until Tenant Approves the Rental Agreement*/ modifier rentalAgreementApproved { require(agreementApproved, "Rental Agreement is not approved"); _; } /*Tenant deposits the rent*/ function deposit() payable rentalAgreementApproved public { uint256 amount = msg.value; depositInfo = AmountInfo({amount:amount, timestamp:now, blockNumber:block.number}); if(ticketInfo.open){ lockedAmount = lockedAmount.add(amount); }else{ availableAmount = availableAmount.add(amount); } Notifier.deposit(msg.sender, amount); emit Deposit(msg.sender, amount, now); } /*Send funds to the contract address so it can process the deposit*/ function () payable public { deposit(); } /*Withdraw the money paid*/ function withdraw() rentalAgreementApproved public { require(msg.sender == clauses.parties.landlord.wallet); uint256 amount = availableAmount; availableAmount = 0; withdrawalInfo = AmountInfo({amount:amount, timestamp:now, blockNumber:block.number}); msg.sender.transfer(amount); Notifier.withdraw(msg.sender, amount); emit Withdraw(msg.sender, amount, now); } /*Increase/Decrease the rent*/ function modifyRent(uint256 newRent) rentalAgreementApproved public { require(msg.sender == clauses.parties.landlord.wallet); rentModificationInfo = AmountInfo({amount:newRent, timestamp:now, blockNumber:block.number}); Notifier.rentModified(msg.sender, newRent); emit RentModified(msg.sender, newRent, now); } /*Open a ticket*/ function openTicket() rentalAgreementApproved public { require(msg.sender == clauses.parties.tenant.wallet); require(!ticketInfo.open); ticketInfo = TicketInfo({open:true, timestamp:now, blockNumber:block.number}); Notifier.ticket(msg.sender, true); emit Ticket(msg.sender, true, now); } /*Close the ticket*/ function closeTicket() public { require(msg.sender == clauses.parties.tenant.wallet || Notifier.admin(msg.sender)); require(ticketInfo.open); ticketInfo = TicketInfo({open:false, timestamp:now, blockNumber:block.number}); uint256 amount = lockedAmount; lockedAmount = 0; availableAmount = availableAmount.add(amount); Notifier.ticket(msg.sender, false); emit Ticket(msg.sender, false, now); } /*Start dispute*/ function startDispute() rentalAgreementApproved public { require(!disputeInfo.onGoing); require(Notifier.admin(msg.sender) || msg.sender == clauses.parties.landlord.wallet || msg.sender == clauses.parties.tenant.wallet); disputeInfo = DisputeInfo({onGoing:true, startedBy:msg.sender, timestamp:now, blockNumber:block.number}); Notifier.dispute(msg.sender, true); emit Dispute(msg.sender, true, now); } /*End dispute*/ function endDispute() public { require(disputeInfo.onGoing); require(msg.sender == disputeInfo.startedBy || Notifier.admin(msg.sender)); disputeInfo = DisputeInfo({onGoing:false, startedBy:disputeInfo.startedBy,timestamp:now, blockNumber:block.number}); Notifier.dispute(msg.sender, false); emit Dispute(msg.sender, false, now); } /*Methods to get contract variables start here*/ function viewFirstBatchOfContractState() public view returns(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256){ return(depositInfo.amount, depositInfo.timestamp, depositInfo.blockNumber, withdrawalInfo.amount, withdrawalInfo.timestamp, withdrawalInfo.blockNumber, rentModificationInfo.amount,rentModificationInfo.timestamp, rentModificationInfo.blockNumber); } function viewSecondBatchOfContractState() public view returns(bool,uint256,uint256,bool,address,uint256,uint256,uint256,uint256,uint256){ return(ticketInfo.open, ticketInfo.timestamp, ticketInfo.blockNumber, disputeInfo.onGoing, disputeInfo.startedBy, disputeInfo.timestamp, disputeInfo.blockNumber, lockedAmount, availableAmount, clauses.terms.rent.amount); } function viewMostRelevantClauses() public view returns(uint256,uint256,uint256){ return (clauses.general.property.Ptype, clauses.terms.rent.paymentDateDay, clauses.general.leaseDetails.dateLeaseStarts); } function viewFirstBatchOfClauses() public view returns(uint256,uint256,uint256,address,address){ return (clauses.general.property.Ptype, clauses.general.leaseDetails.dateLeaseStarts, clauses.property.details.selectedAccessToParking, clauses.parties.tenant.wallet, clauses.parties.landlord.wallet); } function viewSecondBatchOfClauses() public view returns(uint256,uint256,uint256,uint256,uint256,uint256,uint256,uint256, uint256){ return (clauses.parties.selectedOccupantsOptions, clauses.terms.rent.amount, clauses.terms.rent.paymentDateDay, clauses.terms.rentIncrease.selectedIncrementNotice, clauses.terms.rentIncrease.daysNoticeBeforeIncreasingRent, clauses.terms.securityDeposit.amount, clauses.terms.useOfProperty.selectedPetsAllowance, clauses.terms.useOfProperty.selectedSmokingAllowance, clauses.terms.latePayments.selectedLatePayment); } function viewThirdBatchOfClauses() public view returns(uint256,uint256,uint256, uint256[],uint256,uint256,uint256){ return(clauses.terms.latePayments.amount, clauses.terms.latePayments.percentage, clauses.terms.utilitiesDetails.selectedUtilitiesDetails, clauses.terms.utilitiesDetails.utilities, clauses.finalDetails.disputeResolution.selectedDisputeResolution, clauses.finalDetails.disputeResolution.selectedDisputeResolutionCost, clauses.finalDetails.additionalClauses.selectedAdditionalClause); } function tenant() public view returns(address){ return clauses.parties.tenant.wallet; } function landlord() public view returns(address){ return clauses.parties.landlord.wallet; } }