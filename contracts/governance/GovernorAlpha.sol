pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "../libraries/SafeMathExt.sol";

contract GovernorAlpha {

    using SafeMath for uint256;
    using SafeMathExt for uint256;

    /// @notice The name of this contract
    string public constant name = "Mcdex LP Governor Alpha";

    /// @notice The votes ratio in support of a proposal required in order for a quorum to be reached and for a vote to succeed
    function quorumVoteRate() public pure returns (uint256) { return 4e16; } // 4%

    /// @notice The threshold of votes ratio required in order for a voter to become a proposer
    function proposalRateThreshold() public pure returns (uint256) { return 1e16; } // 1%

    /// @notice The maximum number of actions that can be included in a proposal
    function proposalMaxOperations() public pure returns (uint256) { return 10; } // 10 actions

    /// @notice The delay before voting on a proposal may take place, once proposed
    function votingDelay() public pure returns (uint256) { return 1; } // 1 block

    /// @notice The duration of voting on a proposal, in blocks
    function votingPeriod() public pure returns (uint256) { return 17280; } // ~3 days in blocks (assuming 15s blocks)

    /// @notice The address of the Timelock
    TimelockInterface public timelock;

    /// @notice The address of the governance token
    LPShareTokenInterface public lp;

    /// @notice The total number of proposals
    uint256 public proposalCount;

    struct Proposal {
        // Unique id for looking up a proposal
        uint256 id;

        //  Creator of the proposal
        address proposer;

        // the ordered list of target addresses for calls to be made
        address[] targets;

        // The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint256[] values;

        // The ordered list of function signatures to be called
        string[] signatures;

        // The ordered list of calldata to be passed to each call
        bytes[] calldatas;

        // The block at which voting begins: holders must delegate their votes prior to this block
        uint256 startBlock;

        // The block at which voting ends: votes must be cast prior to this block
        uint256 endBlock;

        // Current number of votes in favor of this proposal
        uint256 forVotes;

        // Current number of votes in opposition to this proposal
        uint256 againstVotes;

        // Flag marking whether the proposal has been executed
        bool executed;

        // Receipts of ballots for the entire set of voters
        mapping (address => Receipt) receipts;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        // Whether or not a vote has been cast
        bool hasVoted;

        // Whether or not the voter supports the proposal
        bool support;

        // The number of votes the voter had, which were cast
        uint256 votes;
    }

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Defeated,
        Succeeded,
        Expired,
        Executed
    }

    /// @notice The official record of all proposals ever proposed
    mapping (uint256 => Proposal) public proposals;

    /// @notice The latest proposal for each proposer
    mapping (address => uint256) public latestProposalIds;

    /// @notice The EIP-712 typehash for the contract's domain
    bytes32 public constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

    /// @notice The EIP-712 typehash for the ballot struct used by the contract
    bytes32 public constant BALLOT_TYPEHASH = keccak256("Ballot(uint256 proposalId,bool support)");

    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(uint256 id, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 startBlock, uint256 endBlock, string description);

    /// @notice An event emitted when a vote has been cast on a proposal
    event VoteCast(address voter, uint256 proposalId, bool support, uint256 votes);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint256 id);

    constructor(address timelock_, address lp_) public {
        timelock = TimelockInterface(timelock_);
        lp = LPShareTokenInterface(lp_);
    }

    function propose(address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas, string memory description) public returns (uint256) {
        require(lp.getPriorVotes(msg.sender, block.number.sub(1)) > proposalRateThreshold().wmul(lp.totalSupply()), "GovernorAlpha::propose: proposer votes below proposal threshold");
        require(targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length, "GovernorAlpha::propose: proposal function information arity mismatch");
        require(targets.length != 0, "GovernorAlpha::propose: must provide actions");
        require(targets.length <= proposalMaxOperations(), "GovernorAlpha::propose: too many actions");

        uint256 latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
          ProposalState proposersLatestProposalState = state(latestProposalId);
          require(proposersLatestProposalState != ProposalState.Active, "GovernorAlpha::propose: one live proposal per proposer, found an already active proposal");
          require(proposersLatestProposalState != ProposalState.Pending, "GovernorAlpha::propose: one live proposal per proposer, found an already pending proposal");
        }

        uint256 startBlock = block.number.add(votingDelay());
        uint256 endBlock = startBlock.add(votingPeriod());

        proposalCount++;
        proposals[proposalCount].id = proposalCount;
        proposals[proposalCount].proposer = msg.sender;
        proposals[proposalCount].targets = targets;
        proposals[proposalCount].values = values;
        proposals[proposalCount].signatures = signatures;
        proposals[proposalCount].calldatas = calldatas;
        proposals[proposalCount].startBlock = startBlock;
        proposals[proposalCount].endBlock = endBlock;
        proposals[proposalCount].forVotes = 0;
        proposals[proposalCount].againstVotes = 0;
        proposals[proposalCount].executed = false;

        latestProposalIds[proposals[proposalCount].proposer] = proposalCount;

        emit ProposalCreated(proposalCount, msg.sender, targets, values, signatures, calldatas, startBlock, endBlock, description);
        return proposalCount;
    }

    function execute(uint256 proposalId) public payable {
        require(state(proposalId) == ProposalState.Succeeded, "GovernorAlpha::execute: proposal can only be executed if it is succeeded");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction{ value : proposal.values[i] }(proposal.targets[i], proposal.values[i], proposal.signatures[i], proposal.calldatas[i], proposal.endBlock.add(timelock.delay()));
        }
        emit ProposalExecuted(proposalId);
    }

    function getActions(uint256 proposalId) public view returns (address[] memory targets, uint256[] memory values, string[] memory signatures, bytes[] memory calldatas) {
        Proposal storage p = proposals[proposalId];
        return (p.targets, p.values, p.signatures, p.calldatas);
    }

    function getReceipt(uint256 proposalId, address voter) public view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId && proposalId > 0, "GovernorAlpha::state: invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < quorumVoteRate().wmul(lp.totalSupply())) {
            return ProposalState.Defeated;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.number >= proposal.endBlock.add(timelock.delay()).add(timelock.GRACE_PERIOD())) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Succeeded;
        }
    }

    function castVote(uint256 proposalId, bool support) public {
        return _castVote(msg.sender, proposalId, support);
    }

    function castVoteBySig(uint256 proposalId, bool support, uint8 v, bytes32 r, bytes32 s) public {
        bytes32 domainSeparator = keccak256(abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name)), getChainId(), address(this)));
        bytes32 structHash = keccak256(abi.encode(BALLOT_TYPEHASH, proposalId, support));
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
        address signatory = ecrecover(digest, v, r, s);
        require(signatory != address(0), "GovernorAlpha::castVoteBySig: invalid signature");
        return _castVote(signatory, proposalId, support);
    }

    function _castVote(address voter, uint256 proposalId, bool support) internal {
        require(state(proposalId) == ProposalState.Active, "GovernorAlpha::_castVote: voting is not active");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, "GovernorAlpha::_castVote: voter already voted");
        uint256 votes = lp.getPriorVotes(voter, proposal.startBlock);

        if (support) {
            proposal.forVotes = proposal.forVotes.add(votes);
        } else {
            proposal.againstVotes = proposal.againstVotes.add(votes);
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        emit VoteCast(voter, proposalId, support, votes);
    }

    function getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}

interface TimelockInterface {
    function delay() external view returns (uint256);
    function GRACE_PERIOD() external view returns (uint256);
    function executeTransaction(address target, uint256 value, string calldata signature, bytes calldata data, uint256 eta) external payable returns (bytes memory);
}

interface LPShareTokenInterface {
    function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
