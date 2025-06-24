// SPDX-License-Identifier: UNLICENSE
pragma solidity ^0.8.20;

import {AccessControlled} from "./AccessControlled.sol";

/* A shared interface to support interacting with both ERC20 and ERC721 tokens when only ownership is required.*/
interface IERC20orERC721 {
    function balanceOf(address owner) external view returns (uint256);
}

/* 
 * A smart contract that changes ownership by vote. Voters are allowed to participate based on ownership of an ERC20 or 
 * ERC721 token specified by the initial owner.
 */
abstract contract DemocraticallyOwned is AccessControlled {   

    address private immutable _tokenAddress;

    uint private _nominationStart;
    uint private _nominationDays = 1;   // initialized to guarantee at least 24 hours of nomination by default
    uint private _electionStart;
    uint private _electionDays = 3;     // initialized to guarantee at least 72 hours of voting by default
    uint private _electionEnd;
    bool private _votesTallied = true;  // initialized to true for ownership check

    address[] private _candidates;
    mapping(address => uint) private _lastNomination;
    mapping(address => uint) private _votes;
    mapping(address => uint) private _lastVote;

    error InvalidParticipant(address account);

    event ElectionStarted(uint electionStart, uint electionEnd);
    event CandidateNominated(address indexed candidate);
    event VotesTallied(address indexed winner);

    modifier duringNomination() virtual {
        _duringNomination();
        _;
    }

    modifier notDuringNomination() virtual {
        _notDuringNomination();
        _;
    }

    modifier duringElection() virtual {
        _duringElection();
        _;
    }

    modifier notDuringElection() virtual {
        _notDuringElection();
        _;
    }
    
    constructor(address tokenAddress, address initialOwner) AccessControlled(initialOwner) {
        _tokenAddress = _requireNonZeroAddress(tokenAddress);
    }

    function setNominationDays(uint nominationDays_) external virtual notDuringNomination onlyDelegate {
        require(nominationDays_ > 0, "Nomination period must be at least 1 day.");
        _nominationDays = nominationDays_;
    }

    function setElectionDays(uint electionDays_) external virtual notDuringNomination notDuringElection onlyDelegate {
        require(electionDays_ > 0, "Election period must be at least 1 day.");
        _electionDays = electionDays_;
    }

    function vote(address candidate) external virtual duringElection onlyAllowed {
        if (hasVoted(_msgSender())) revert("Voter has already voted this election.");
        if (!isCandidate(candidate)) revert("Selected address is not a nomiated candidate.");
        if (!canParticipate(candidate)) revert InvalidParticipant(candidate);
        _lastVote[_msgSender()] = block.timestamp;
        _votes[candidate] += 1;
    }

    function nominate(address candidate) public virtual nonZeroAddress(candidate) duringNomination onlyAllowed {
        if (_msgSender() == candidate) revert("Candidates cannot nominate themselves.");
        if (!canParticipate(candidate)) revert InvalidParticipant(candidate);
        if (isCandidate(candidate)) revert("Candidate has already been nominated.");
        _candidates.push(candidate);
        _lastNomination[candidate] = block.timestamp;
        _votes[candidate] = 0;
        emit CandidateNominated(candidate);
    }

    // Tallies the votes, clears the delegate list, and transfers ownership to the winner post-election.
    // If there are no votes or candidates, ownership will be transferred to the zero address (renouncement).
    function tally() public virtual notDuringNomination notDuringElection onlyAllowed {
        if (_votesTallied) revert("Vote has already been called.");
        address voteLeader_ = address(0);
        uint mostVotes_ = 0;
        for (uint i = 0; i < _candidates.length; i++) {
            address candidate_ = _candidates[i];
            if (!canParticipate(candidate_)) continue;
            uint votesFor_ = _votes[candidate_];
            if (votesFor_ > mostVotes_) {
                mostVotes_ = votesFor_;
                voteLeader_ = candidate_;
            }
        }
        _votesTallied = true;
        if (voteLeader_ != owner()) {
            _clearDelegates();
            _transferOwnership(voteLeader_);
        }
        emit VotesTallied(owner());
    }

    // Instead of transferring ownership to the zero address, the owner starts a new election with no nominees.
    // Function is limited to onlyOwner since a completed election with no nominees will transfer to the 0 address.
    function renounceOwnership() public override onlyOwner {
        _startElection();
    }

    // Attempts to transfer ownership by starting an election for the new one and nominating the proposed address.
    // Lacks the onlyOwner restriction so any valid participant can kick off an election.
    function transferOwnership(address candidate) public override onlyAllowed {
        _startElection();
        nominate(candidate);
    }

    function canParticipate(address voter) public virtual view returns (bool) {
        return IERC20orERC721(_tokenAddress).balanceOf(voter) > 0;
    }

    function hasVoted(address voter) public virtual view returns (bool) {
        return _lastVote[voter] >= _electionStart;
    }

    function isCandidate(address candidate) public virtual view returns (bool) {
        return _lastNomination[candidate] >= _nominationStart;
    }

    function nominationDays() public virtual view returns (uint) {
        return _nominationDays;
    }

    function electionDays() public virtual view returns (uint) {
        return _electionDays;
    }

    function isNominationPeriod() public virtual view returns (bool) {
        return (_nominationStart <= block.timestamp && block.timestamp < _electionStart);
    }

    function isElectionPeriod() public virtual view returns (bool) {
        return (_electionStart <= block.timestamp && block.timestamp < _electionEnd);
    }

    function owner() public override view returns (address) {
        if (!isNominationPeriod() && !isElectionPeriod() && !_votesTallied)
            revert("Election for new contract owner has been held but not tallied. Call tally() first.");
        return super.owner();
    }

    function _duringNomination() internal virtual {
        if (!isNominationPeriod()) revert("Operation is only available during the nomination period.");
    } 

    function _notDuringNomination() internal virtual {
        if (isNominationPeriod()) revert("Operation is not available during nominations.");
    }
 
    function _duringElection() internal virtual {
        if (!isElectionPeriod()) revert("Operation is only available during an election.");
    } 

    function _notDuringElection() internal virtual {
        if (isElectionPeriod()) revert("Operation is not available during elections.");
    }

    function _startElection() internal virtual whenNotPaused notDuringNomination notDuringElection {
        if (!_votesTallied) revert("Outcome of prior election pending. Call tally() first.");
        _nominationStart = block.timestamp;
        _electionStart = block.timestamp + (_nominationDays * 1 days);
        _electionEnd = _electionStart + (_electionDays * 1 days);
        _votesTallied = false;
        emit ElectionStarted(_electionStart, _electionEnd);
    }

    // Override to add ownership of related token as an access requirement.
    function _checkDelegate() internal override view {
        if (!canParticipate(_msgSender())) revert InvalidParticipant(_msgSender());
        super._checkDelegate();
    }

    // Override to add ownership of related token as an access requirement.
    function _checkAllowed() internal override view {
        if (!canParticipate(_msgSender())) revert InvalidParticipant(_msgSender());
        super._checkAllowed();
    }
}