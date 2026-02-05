// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding{
    address public owner;
    uint public goal;
    uint public deadline;
    uint public totalFunds;

    mapping(address => uint) public contributions;


// constructor function -> set up the smart contract
    constructor(uint _goal, uint _durationDays) {
        owner = msg.sender; // Creator becomes owner
        goal = _goal;
        deadline = block.timestamp + (_durationDays * 1 days); // Set deadline from now + days
    }
    // message properties: 
    // msg.sender - address of the sender of the message
    // msg.value - amount of eth sent with the message

    // block.number - block of origional transaction that triggered this execution
    // block.timestamp = when that block was mined 

    function contribute() public payable{
        require(block.timestamp < deadline, "Campaign ended");
        require(msg.value > 0, "Must send ETH");    // essentially an if else statment

        contributions[msg.sender] += msg.value;
        totalFunds += msg.value;
    }

    function withdraw() public {
        require(msg.sender == owner, "Only owner can withdraw");
        require(block.timestamp >= deadline, "Campaign still active");
        require(totalFunds >= goal, "Goal not reached");

        (bool success, ) = payable(owner).call{value:address(this).balance}("");
        // sends money to owner, address(this) is the smart contracts own address
        require(success, "Transfer failed");
    }

    function refund() public {
        require(block.timestamp >= deadline, "Campaign still active");
        require(totalFunds < goal, "Goal was reached");

        uint amount = contributions[msg.sender];
        require(amount > 0, "No contribution found");
    }

    function getContractBalance() public view returns (uint) {
        return address(this).balance;
    }
}