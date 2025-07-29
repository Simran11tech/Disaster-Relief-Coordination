// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Disaster Relief Coordination
 * @dev Smart contract for coordinating disaster relief efforts, donations, and resource distribution
 */
contract DisasterReliefCoordination {
    
    // Struct to represent a disaster event
    struct Disaster {
        uint256 id;
        string name;
        string location;
        string description;
        uint256 targetAmount;
        uint256 raisedAmount;
        uint256 timestamp;
        bool isActive;
        address coordinator;
    }
    
    // Struct to represent relief requests
    struct ReliefRequest {
        uint256 id;
        uint256 disasterId;
        address requester;
        string resourceType;
        uint256 quantity;
        string urgencyLevel;
        bool isFulfilled;
        uint256 timestamp;
    }
    
    // Struct to represent donations
    struct Donation {
        address donor;
        uint256 disasterId;
        uint256 amount;
        uint256 timestamp;
    }
    
    // State variables
    address public owner;
    uint256 public disasterCounter;
    uint256 public requestCounter;
    uint256 public totalDonations;
    
    // Mappings
    mapping(uint256 => Disaster) public disasters;
    mapping(uint256 => ReliefRequest) public reliefRequests;
    mapping(address => bool) public authorizedCoordinators;
    mapping(uint256 => Donation[]) public disasterDonations;
    mapping(address => uint256) public donorContributions;
    
    // Events
    event DisasterRegistered(uint256 indexed disasterId, string name, string location, address coordinator);
    event DonationReceived(address indexed donor, uint256 indexed disasterId, uint256 amount);
    event ReliefRequested(uint256 indexed requestId, uint256 indexed disasterId, address requester, string resourceType);
    event ReliefFulfilled(uint256 indexed requestId, uint256 indexed disasterId);
    event FundsWithdrawn(uint256 indexed disasterId, uint256 amount, address coordinator);
    event CoordinatorAuthorized(address indexed coordinator);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyAuthorizedCoordinator() {
        require(authorizedCoordinators[msg.sender] || msg.sender == owner, "Not authorized coordinator");
        _;
    }
    
    modifier disasterExists(uint256 _disasterId) {
        require(_disasterId > 0 && _disasterId <= disasterCounter, "Disaster does not exist");
        _;
    }
    
    modifier disasterActive(uint256 _disasterId) {
        require(disasters[_disasterId].isActive, "Disaster relief is not active");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        authorizedCoordinators[msg.sender] = true;
    }
    
    /**
     * @dev Core Function 1: Register a new disaster and start relief coordination
     * @param _name Name of the disaster
     * @param _location Location affected by the disaster
     * @param _description Description of the disaster and needs
     * @param _targetAmount Target amount needed for relief efforts
     */
    function registerDisaster(
        string memory _name,
        string memory _location,
        string memory _description,
        uint256 _targetAmount
    ) external onlyAuthorizedCoordinator {
        require(bytes(_name).length > 0, "Disaster name cannot be empty");
        require(bytes(_location).length > 0, "Location cannot be empty");
        require(_targetAmount > 0, "Target amount must be greater than 0");
        
        disasterCounter++;
        
        disasters[disasterCounter] = Disaster({
            id: disasterCounter,
            name: _name,
            location: _location,
            description: _description,
            targetAmount: _targetAmount,
            raisedAmount: 0,
            timestamp: block.timestamp,
            isActive: true,
            coordinator: msg.sender
        });
        
        emit DisasterRegistered(disasterCounter, _name, _location, msg.sender);
    }
    
    /**
     * @dev Core Function 2: Accept donations for disaster relief
     * @param _disasterId ID of the disaster to donate to
     */
    function donate(uint256 _disasterId) external payable disasterExists(_disasterId) disasterActive(_disasterId) {
        require(msg.value > 0, "Donation amount must be greater than 0");
        
        disasters[_disasterId].raisedAmount += msg.value;
        totalDonations += msg.value;
        donorContributions[msg.sender] += msg.value;
        
        // Record the donation
        disasterDonations[_disasterId].push(Donation({
            donor: msg.sender,
            disasterId: _disasterId,
            amount: msg.value,
            timestamp: block.timestamp
        }));
        
        emit DonationReceived(msg.sender, _disasterId, msg.value);
    }
    
    /**
     * @dev Core Function 3: Submit relief requests and manage resource distribution
     * @param _disasterId ID of the disaster
     * @param _resourceType Type of resource needed (food, water, medical, shelter, etc.)
     * @param _quantity Quantity of resources needed
     * @param _urgencyLevel Urgency level (high, medium, low)
     */
    function requestRelief(
        uint256 _disasterId,
        string memory _resourceType,
        uint256 _quantity,
        string memory _urgencyLevel
    ) external disasterExists(_disasterId) disasterActive(_disasterId) {
        require(bytes(_resourceType).length > 0, "Resource type cannot be empty");
        require(_quantity > 0, "Quantity must be greater than 0");
        
        requestCounter++;
        
        reliefRequests[requestCounter] = ReliefRequest({
            id: requestCounter,
            disasterId: _disasterId,
            requester: msg.sender,
            resourceType: _resourceType,
            quantity: _quantity,
            urgencyLevel: _urgencyLevel,
            isFulfilled: false,
            timestamp: block.timestamp
        });
        
        emit ReliefRequested(requestCounter, _disasterId, msg.sender, _resourceType);
    }
    
    /**
     * @dev Mark a relief request as fulfilled
     * @param _requestId ID of the relief request
     */
    function fulfillReliefRequest(uint256 _requestId) external onlyAuthorizedCoordinator {
        require(_requestId > 0 && _requestId <= requestCounter, "Request does not exist");
        require(!reliefRequests[_requestId].isFulfilled, "Request already fulfilled");
        
        reliefRequests[_requestId].isFulfilled = true;
        
        emit ReliefFulfilled(_requestId, reliefRequests[_requestId].disasterId);
    }
    
    /**
     * @dev Withdraw funds for disaster relief operations
     * @param _disasterId ID of the disaster
     * @param _amount Amount to withdraw
     */
    function withdrawFunds(uint256 _disasterId, uint256 _amount) external disasterExists(_disasterId) {
        require(msg.sender == disasters[_disasterId].coordinator, "Only disaster coordinator can withdraw");
        require(_amount <= disasters[_disasterId].raisedAmount, "Insufficient funds");
        require(address(this).balance >= _amount, "Contract has insufficient balance");
        
        disasters[_disasterId].raisedAmount -= _amount;
        
        payable(msg.sender).transfer(_amount);
        
        emit FundsWithdrawn(_disasterId, _amount, msg.sender);
    }
    
    /**
     * @dev Authorize a new coordinator
     * @param _coordinator Address of the new coordinator
     */
    function authorizeCoordinator(address _coordinator) external onlyOwner {
        require(_coordinator != address(0), "Invalid coordinator address");
        authorizedCoordinators[_coordinator] = true;
        
        emit CoordinatorAuthorized(_coordinator);
    }
    
    /**
     * @dev Deactivate a disaster relief campaign
     * @param _disasterId ID of the disaster
     */
    function deactivateDisaster(uint256 _disasterId) external disasterExists(_disasterId) {
        require(msg.sender == disasters[_disasterId].coordinator, "Only disaster coordinator can deactivate");
        disasters[_disasterId].isActive = false;
    }
    
    /**
     * @dev Get disaster details
     * @param _disasterId ID of the disaster
     */
    function getDisasterDetails(uint256 _disasterId) external view disasterExists(_disasterId) returns (
        string memory name,
        string memory location,
        string memory description,
        uint256 targetAmount,
        uint256 raisedAmount,
        bool isActive,
        address coordinator
    ) {
        Disaster memory disaster = disasters[_disasterId];
        return (
            disaster.name,
            disaster.location,
            disaster.description,
            disaster.targetAmount,
            disaster.raisedAmount,
            disaster.isActive,
            disaster.coordinator
        );
    }
    
    /**
     * @dev Get relief request details
     * @param _requestId ID of the relief request
     */
    function getReliefRequestDetails(uint256 _requestId) external view returns (
        uint256 disasterId,
        address requester,
        string memory resourceType,
        uint256 quantity,
        string memory urgencyLevel,
        bool isFulfilled
    ) {
        require(_requestId > 0 && _requestId <= requestCounter, "Request does not exist");
        ReliefRequest memory request = reliefRequests[_requestId];
        return (
            request.disasterId,
            request.requester,
            request.resourceType,
            request.quantity,
            request.urgencyLevel,
            request.isFulfilled
        );
    }
    
    /**
     * @dev Get total donations for a disaster
     * @param _disasterId ID of the disaster
     */
    function getDisasterDonationCount(uint256 _disasterId) external view disasterExists(_disasterId) returns (uint256) {
        return disasterDonations[_disasterId].length;
    }
    
    /**
     * @dev Get contract balance
     */
    function getContractBalance() external view returns (uint256) {
        return address(this).balance;
    }
}
