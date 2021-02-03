// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.4;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/GSN/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";

// import "hardhat/console.sol";

interface ILiquidityPool {
    function getLiquidityPoolInfo()
        external
        view
        returns (
            bool isRunning,
            bool isFastCreationEnabled,
            // [0] creator,
            // [1] operator,
            // [2] transferringOperator,
            // [3] governor,
            // [4] shareToken,
            // [5] collateralToken,
            // [6] vault,
            address[7] memory addresses,
            int256 vaultFeeRate,
            int256 poolCash,
            uint256 collateralDecimals,
            uint256 perpetualCount,
            uint256 fundingTime
        );
}

/// @notice Possible states that a proposal may be in
enum ProposalState { Pending, Active, Canceled, Defeated, Succeeded, Queued, Expired, Executed }

struct Proposal {
    // Unique id for looking up a proposal
    uint256 id;
    // Creator of the proposal
    address proposer;
    // The timestamp that the proposal will be available for execution, set once the vote succeeds
    uint256 eta;
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
    // Flag marking whether the proposal has been canceled
    bool canceled;
    // Flag marking whether the proposal has been executed
    bool executed;
    // Receipts of ballots for the entire set of voters
    mapping(address => Receipt) receipts;
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

abstract contract GovernorAlpha is Initializable, ContextUpgradeable {
    using SafeMathUpgradeable for uint256;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    bytes32 public constant SIGNATURE_PERPETUAL_UPGRADE =
        keccak256(bytes("upgradeTo(address,address)"));
    bytes32 public constant SIGNATURE_PERPETUAL_SETTLE =
        keccak256(bytes("forceToSetEmergencyState(uint256)"));
    bytes32 public constant SIGNATURE_PERPETUAL_SET_OPERATOR =
        keccak256(bytes("setOperator(address)"));

    address internal _target;

    mapping(address => uint256) internal _voteLocks;
    mapping(address => EnumerableSetUpgradeable.UintSet) internal _supportedProposals;

    /// @notice The total number of proposals
    uint256 public proposalCount;

    /// @notice The official record of all proposals ever proposed
    mapping(uint256 => Proposal) public proposals;

    /// @notice The latest proposal for each proposer
    mapping(address => uint256) public latestProposalIds;

    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(
        uint256 id,
        address proposer,
        string[] signatures,
        bytes[] calldatas,
        uint256 startBlock,
        uint256 endBlock,
        string description
    );
    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        string signature,
        bytes data,
        uint256 eta
    );
    /// @notice An event emitted when a vote has been cast on a proposal
    event VoteCast(address voter, uint256 proposalId, bool support, uint256 votes);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint256 id);

    function __GovernorAlpha_init_unchained(address target) internal initializer {
        _target = target;
    }

    // virtual methods
    function balanceOf(address account) public view virtual returns (uint256);

    function totalSupply() public view virtual returns (uint256);

    /// @notice The number of votes in support of a proposal required in order for a quorum to be reached
    ///         and for a vote to succeed
    function quorumRate() public pure virtual returns (uint256) {
        return 1e17;
    }

    /// @notice The number of votes in support of a proposal required in order for a quorum to be reached
    ///         and for a vote to succeed
    function criticalQuorumRate() public pure virtual returns (uint256) {
        return 2e17;
    }

    /// @notice The number of votes required in order for a voter to become a proposer
    function proposalThresholdRate() public pure virtual returns (uint256) {
        return 1e16;
    }

    /// @notice The maximum number of actions that can be included in a proposal
    function proposalMaxOperations() public pure virtual returns (uint256) {
        return 10;
    }

    /// @notice The delay before voting on a proposal may take place, once proposed
    function votingDelay() public pure virtual returns (uint256) {
        return 1;
    }

    /// @notice The duration of voting on a proposal, in blocks
    function votingPeriod() public pure virtual returns (uint256) {
        return 17280;
    }

    function executionDelay() public pure virtual returns (uint256) {
        return 11520;
    }

    function unlockPeriod() public pure virtual returns (uint256) {
        return 17280;
    }

    function isCriticalFunction(string memory functionSignature) public pure returns (bool) {
        bytes32 functionHash = keccak256(bytes(functionSignature));
        return
            functionHash == SIGNATURE_PERPETUAL_UPGRADE ||
            functionHash == SIGNATURE_PERPETUAL_SETTLE ||
            functionHash == SIGNATURE_PERPETUAL_SET_OPERATOR;
    }

    function getProposalPriorThreshold() public view virtual returns (uint256) {
        uint256 totalVotes = totalSupply();
        return totalVotes.mul(proposalThresholdRate()).div(1e18);
    }

    function getQuorumVotes(uint256 proposalId) public view virtual returns (uint256) {
        uint256 totalVotes = totalSupply();
        Proposal storage proposal = proposals[proposalId];
        for (uint256 i = 0; i < proposal.signatures.length; i++) {
            if (isCriticalFunction(proposal.signatures[i])) {
                return totalVotes.mul(criticalQuorumRate()).div(1e18);
            }
        }
        return totalVotes.mul(quorumRate()).div(1e18);
    }

    function execute(uint256 proposalId) public payable {
        require(
            state(proposalId) == ProposalState.Succeeded,
            "proposal can only be executed if it is success and queued"
        );
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        for (uint256 i = 0; i < proposal.signatures.length; i++) {
            _executeTransaction(proposal.signatures[i], proposal.calldatas[i], proposal.endBlock);
        }
        emit ProposalExecuted(proposalId);
    }

    function canPropose(address voter) public view virtual returns (bool) {
        address operator = _getOperator();
        if (operator == address(0)) {
            // if pool has not a operator, then only any one with enough lp token is able to propose
            return balanceOf(voter) >= getProposalPriorThreshold();
        } else {
            // or only operator is able to propose
            return operator == voter;
        }
    }

    function getActions(uint256 proposalId)
        public
        view
        returns (string[] memory signatures, bytes[] memory calldatas)
    {
        Proposal storage p = proposals[proposalId];
        return (p.signatures, p.calldatas);
    }

    function getReceipt(uint256 proposalId, address voter) public view returns (Receipt memory) {
        return proposals[proposalId].receipts[voter];
    }

    function state(uint256 proposalId) public view returns (ProposalState) {
        require(proposalCount >= proposalId && proposalId > 0, "invalid proposal id");
        Proposal storage proposal = proposals[proposalId];
        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.startBlock) {
            return ProposalState.Pending;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (
            proposal.forVotes <= proposal.againstVotes ||
            proposal.forVotes < getQuorumVotes(proposalId)
        ) {
            return ProposalState.Defeated;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.number <= proposal.endBlock.add(executionDelay())) {
            return ProposalState.Queued;
        } else if (block.number > proposal.endBlock.add(executionDelay()).add(unlockPeriod())) {
            return ProposalState.Expired;
        } else {
            return ProposalState.Succeeded;
        }
    }

    function castVote(uint256 proposalId, bool support) public virtual {
        address voter = _msgSender();
        require(state(proposalId) == ProposalState.Active, "voting is closed");
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[voter];
        require(receipt.hasVoted == false, "voter already voted");
        uint256 votes = balanceOf(voter);

        if (support) {
            proposal.forVotes = proposal.forVotes.add(votes);
        } else {
            proposal.againstVotes = proposal.againstVotes.add(votes);
        }

        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;

        _setVoteLock(voter, proposal.startBlock.add(votingPeriod()));
        if (support) {
            _supportedProposals[voter].add(proposalId);
        }

        emit VoteCast(voter, proposalId, support, votes);
    }

    function isLockedByVoting(address account) public virtual returns (bool) {
        if (account == address(0)) {
            return false;
        }
        _updateVoteLock(account);
        return _getBlockNumber() <= _voteLocks[account];
    }

    function _setVoteLock(address account, uint256 blockNumber) internal {
        if (blockNumber > _voteLocks[account]) {
            _voteLocks[account] = blockNumber;
        }
    }

    function _updateVoteLock(address account) internal virtual {
        EnumerableSetUpgradeable.UintSet storage proposalIds = _supportedProposals[account];
        uint256 length = proposalIds.length();
        for (uint256 i = 0; i < length; i++) {
            uint256 proposalId = proposalIds.at(i);
            ProposalState proposalState = state(proposalId);
            if (proposalState == ProposalState.Pending || proposalState == ProposalState.Active) {
                continue;
            }
            if (
                proposalState == ProposalState.Succeeded ||
                proposalState == ProposalState.Executed ||
                proposalState == ProposalState.Queued
            ) {
                uint256 unlockBlock =
                    proposals[proposalId].endBlock.add(executionDelay().add(unlockPeriod()));
                if (unlockBlock > _voteLocks[account]) {
                    _voteLocks[account] = unlockBlock;
                }
            }
            proposalIds.remove(proposalId);
        }
    }

    function _getOperator() internal view returns (address) {
        (, , address[7] memory addresses, , , , , ) =
            ILiquidityPool(_target).getLiquidityPoolInfo();
        return addresses[1];
    }

    function propose(
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) public virtual returns (uint256) {
        address proposer = _msgSender();
        require(signatures.length == calldatas.length, "function information arity mismatch");
        require(signatures.length != 0, "must provide actions");
        require(signatures.length <= proposalMaxOperations(), "too many actions");
        require(canPropose(proposer), "requirements not satisfied for proposer");
        if (latestProposalIds[proposer] != 0) {
            ProposalState latestProposalState = state(latestProposalIds[proposer]);
            require(latestProposalState != ProposalState.Active, "last proposal is active");
            require(latestProposalState != ProposalState.Pending, "last proposal is pending");
        }
        uint256 startBlock = _getBlockNumber().add(votingDelay());
        uint256 endBlock = startBlock.add(votingPeriod());
        uint256 voteBalance = balanceOf(proposer);

        proposalCount++;
        uint256 proposalId = proposalCount;
        proposals[proposalId].id = proposalId;
        proposals[proposalId].proposer = proposer;
        proposals[proposalId].signatures = signatures;
        proposals[proposalId].calldatas = calldatas;
        proposals[proposalId].startBlock = startBlock;
        proposals[proposalId].endBlock = endBlock;
        proposals[proposalId].forVotes = voteBalance;
        proposals[proposalId].receipts[proposer] = Receipt({
            hasVoted: true,
            support: true,
            votes: voteBalance
        });
        latestProposalIds[proposer] = proposalId;
        emit VoteCast(proposer, proposalId, true, voteBalance);

        emit ProposalCreated(
            proposalId,
            proposer,
            signatures,
            calldatas,
            startBlock,
            endBlock,
            description
        );
        return proposalId;
    }

    function _executeTransaction(
        string memory signature,
        bytes memory data,
        uint256 eta
    ) internal returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(_target, signature, data, eta));
        uint256 blockNumber = _getBlockNumber();
        require(
            blockNumber >= eta.add(executionDelay()),
            "Transaction hasn't surpassed time lock."
        );
        require(
            blockNumber <= eta.add(executionDelay()).add(unlockPeriod()),
            "Transaction is stale."
        );

        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }
        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = _target.call(callData);
        require(success, "Transaction execution reverted.");
        emit ExecuteTransaction(txHash, _target, signature, data, eta);
        return returnData;
    }

    function _getBlockNumber() internal view virtual returns (uint256) {
        return block.number;
    }

    bytes32[50] private __gap;
}
