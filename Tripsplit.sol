// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title TripSplit - a simple group trip pool with vote-to-pay proposals
/// @notice Teaching example: threshold approvals (mini multisig), proposals, voting, events, safe ETH transfers
contract TripSplit {
    // --- Reentrancy guard ---
    uint256 private unlocked = 1;
    modifier nonReentrant() {
        require(unlocked == 1, "Reentrancy");
        unlocked = 2;
        _;
        unlocked = 1;
    }

    // --- Hardcoded members (for teaching/demo purposes) ---
    address[] public members = [
        0x17F6AD8Ef982297579C203069C1DbfFE4348c372,
        0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2,
        0x5B38Da6a701c568545dCfcB03FcB875f56beddC4
    ];

    mapping(address => bool) public isMember;

    // Minimum number of approvals required to execute a proposal
    uint256 public threshold = 2;

    uint256 public poolBalance;

    struct Proposal {
        address proposer;
        address payable to;
        uint256 amount;
        string memo;     // e.g. "Airbnb deposit", "Car rental", "Refund Alex"
        uint256 approvals;
        bool executed;
    }

    Proposal[] public proposals;

    // proposalId => member => approved?
    mapping(uint256 => mapping(address => bool)) public approvedBy;

    event Deposited(address indexed from, uint256 amount, uint256 newPoolBalance);
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        address indexed to,
        uint256 amount,
        string memo
    );
    event Approved(uint256 indexed proposalId, address indexed member, uint256 approvals);
    event Executed(uint256 indexed proposalId, address indexed to, uint256 amount);

    modifier onlyMember() {
        require(isMember[msg.sender], "Not a member");
        _;
    }

    /// @notice Constructor initializes membership mapping
    constructor() {
        for (uint256 i = 0; i < members.length; i++) {
            isMember[members[i]] = true;
        }
    }

    /// @notice Any member can deposit ETH into the shared pool
    function deposit() external payable onlyMember {
        require(msg.value > 0, "No ETH");
        poolBalance += msg.value;
        emit Deposited(msg.sender, msg.value, poolBalance);
    }

    /// @notice Create a payment proposal (needs approvals to execute)
    function createProposal(
        address payable to,
        uint256 amount,
        string calldata memo
    )
        external
        onlyMember
        returns (uint256 proposalId)
    {
        require(to != address(0), "To=0");
        require(amount > 0, "Amount=0");
        require(amount <= poolBalance, "Not enough in pool");

        proposals.push(Proposal({
            proposer: msg.sender,
            to: to,
            amount: amount,
            memo: memo,
            approvals: 0,
            executed: false
        }));

        proposalId = proposals.length - 1;
        emit ProposalCreated(proposalId, msg.sender, to, amount, memo);
    }

    /// @notice Approve a proposal (one vote per member)
    function approveProposal(uint256 proposalId) external onlyMember {
        require(proposalId < proposals.length, "Bad id");

        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Already executed");
        require(!approvedBy[proposalId][msg.sender], "Already approved");

        approvedBy[proposalId][msg.sender] = true;
        p.approvals += 1;

        emit Approved(proposalId, msg.sender, p.approvals);
    }

    /// @notice Execute proposal if approvals reach threshold
    function executeProposal(uint256 proposalId)
        external
        nonReentrant
        onlyMember
    {
        require(proposalId < proposals.length, "Bad id");

        Proposal storage p = proposals[proposalId];
        require(!p.executed, "Already executed");
        require(p.approvals >= threshold, "Not enough approvals");
        require(p.amount <= poolBalance, "Pool changed");

        // Effects
        p.executed = true;
        poolBalance -= p.amount;

        // Interaction
        (bool ok, ) = p.to.call{value: p.amount}("");
        require(ok, "Payment failed");

        emit Executed(proposalId, p.to, p.amount);
    }

    // --- Read helpers for frontends / teaching ---

    function memberCount() external view returns (uint256) {
        return members.length;
    }

    function proposalCount() external view returns (uint256) {
        return proposals.length;
    }

    function getProposal(uint256 proposalId)
        external
        view
        returns (
            address proposer,
            address to,
            uint256 amount,
            string memory memo,
            uint256 approvals,
            bool executed
        )
    {
        Proposal storage p = proposals[proposalId];
        return (
            p.proposer,
            p.to,
            p.amount,
            p.memo,
            p.approvals,
            p.executed
        );
    }
}
