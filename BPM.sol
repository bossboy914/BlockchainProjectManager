// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract ConstructionContract is Ownable, Initializable, ReentrancyGuard {
    using SafeMath for uint256;

    // Immutable variables
    address public immutable contractor;
    address public immutable regulator;

    // State variables
    uint256 public budget;
    bool public isSafetyCompliant = true;
    bool public isBudgetApproved = false;

    // Enums
    enum Phase { PreConstruction, Construction, PostConstruction, Maintenance }
    Phase public currentPhase = Phase.PreConstruction;

    enum Milestone { Foundation, Framing, Roofing, Interior, Handover }
    mapping(Milestone => bool) public isMilestoneCompleted;

    // Subcontractor management
    mapping(address => bool) public pendingSubcontractors;
    mapping(address => bool) public approvedSubcontractors;

    // Dispute resolution
    enum DisputeStatus { Open, Resolved }
    struct Dispute {
        string reason;
        DisputeStatus status;
    }
    Dispute[] public disputes;

    // Events
    event BudgetApproved(uint256 newBudget);
    event MilestoneCompleted(Milestone milestone);
    event SafetyViolation(string reason);
    event SafetyComplianceRegained();
    event PaymentMade(address to, uint256 amount);
    event PhaseChanged(Phase newPhase);
    event SubcontractorPending(address subcontractor);
    event SubcontractorApproved(address subcontractor);
    event DisputeOpened(uint256 disputeId, string reason);
    event DisputeResolved(uint256 disputeId);

    // Modifiers
    modifier onlyRegulator() {
        require(msg.sender == regulator, "Only the regulator can call this function");
        _;
    }

    modifier onlyContractorOrSubcontractor() {
        require(msg.sender == contractor || approvedSubcontractors[msg.sender], "Only contractor or approved subcontractor can call this function");
        _;
    }

    modifier atPhase(Phase _phase) {
        require(currentPhase == _phase, "Not the correct phase for this action");
        _;
    }

    // Initialization
    function initialize(address _contractor, address _regulator, uint256 _budget) public initializer onlyOwner {
        contractor = _contractor;
        regulator = _regulator;
        budget = _budget;
    }

    // Budget approval
    function approveBudget(uint256 _budget) external onlyOwner atPhase(Phase.PreConstruction) {
        require(!isBudgetApproved, "Budget has already been approved");
        budget = _budget;
        isBudgetApproved = true;
        emit BudgetApproved(_budget);
    }

    // Milestone completion
    function completeMilestone(Milestone _milestone) external onlyContractorOrSubcontractor atPhase(Phase.Construction) {
        require(!isMilestoneCompleted[_milestone], "Milestone already completed");
        isMilestoneCompleted[_milestone] = true;
        emit MilestoneCompleted(_milestone);
    }

    // Safety violations
    function recordSafetyViolation(string calldata reason) external onlyRegulator {
        isSafetyCompliant = false;
        emit SafetyViolation(reason);
    }

    // Regain safety compliance
    function regainSafetyCompliance() external onlyRegulator {
        isSafetyCompliant = true;
        emit SafetyComplianceRegained();
    }

    // Payment
    function makePayment(address payable to, uint256 amount) external onlyOwner nonReentrant {
        require(budget >= amount, "Insufficient budget");
        budget = budget.sub(amount);
        to.transfer(amount);
        emit PaymentMade(to, amount);
    }

    // Phase change
    function changePhase(Phase _newPhase) external onlyOwner {
        require(uint(_newPhase) > uint(currentPhase), "Invalid phase transition");
        currentPhase = _newPhase;
        emit PhaseChanged(_newPhase);
    }

    // Subcontractor management
    function addPendingSubcontractor(address _subcontractor) external onlyContractorOrSubcontractor {
        pendingSubcontractors[_subcontractor] = true;
        emit SubcontractorPending(_subcontractor);
    }

    function approveSubcontractor(address _subcontractor) external onlyOwner {
        require(pendingSubcontractors[_subcontractor], "Subcontractor not pending");
        approvedSubcontractors[_subcontractor] = true;
        emit SubcontractorApproved(_subcontractor);
    }

    // Dispute resolution
    function openDispute(string calldata reason) external onlyContractorOrSubcontractor {
        disputes.push(Dispute(reason, DisputeStatus.Open));
        emit DisputeOpened(disputes.length - 1, reason);
    }

    function resolveDispute(uint256 disputeId) external onlyOwner {
        require(disputeId < disputes.length, "Invalid dispute ID");
        require(disputes[disputeId].status == DisputeStatus.Open, "Dispute already resolved");
        disputes[disputeId].status = DisputeStatus.Resolved;
        emit DisputeResolved(disputeId);
    }

    // Fallback function
    receive() external payable {
        revert("Direct payments not allowed");
    }
}
