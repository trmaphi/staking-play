// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract Staking is ReentrancyGuard {
    uint256 public constant REWARD_PER_BLOCK = 100e18; // 100 tokens per block
    struct StakeInfo {
        uint256 stakedAmount;
        uint128 blockNum;       // block.number - save storage
        uint128 blockTimestamp; // block.timestamp - save storage
    }

    mapping(address => StakeInfo) public stakes;
    uint256 public totalDepositAmt;
    ERC20 public token;

    constructor(ERC20 _token) {
        require(address(_token) != address(0), "Invalid token address");
        token = _token;
    }
    
    event Staked(address indexed user, uint256 indexed amount);
    event Unstaked(address indexed user, uint256 indexed amount);

    function stake(uint256 _amount) external nonReentrant {
        require(_amount != 0, "Cannot stake 0 tokens");

        // msg.sender must ERC20.approve this contract before stake
        token.transferFrom(msg.sender, address(this), _amount);

        // Recalculate current reward
        uint256 reward = calculateReward(msg.sender);
        
        // Override current stake with current reward 
        stakes[msg.sender].stakedAmount = stakes[msg.sender].stakedAmount + reward + _amount;
        stakes[msg.sender].blockNum = uint128(block.number);
        stakes[msg.sender].blockTimestamp = uint128(block.timestamp);

        // If continue to stake the ratio of staker (stakedAmount/totalDepositAmt) will be bigger
        totalDepositAmt += _amount;

        emit Staked(msg.sender, _amount);
    }

    function calculateReward(address _staker) public view returns(uint256) {
        StakeInfo memory stakerInfo = stakes[_staker];
        // If staker has not staked any tokens, return 0
        // If staker withdraws tokens, return 0
        if (stakerInfo.stakedAmount == 0) {
            return 0;
        }

        // If staker has staked tokens within the last 24 hours, return 0
        if ((block.timestamp - stakerInfo.blockTimestamp) <= 1 days) {
            return 0;
        }

        // Total reward in block A -> B on totalReward = (block.number - stakerInfo.blockNum) * REWARD_PER_BLOCK
        // Ratio of staker's deposit to total deposit = stakerInfo.stakedAmount / totalDepositAmt 
        // ((block.number - stakerInfo.blockNum) * REWARD_PER_BLOCK ) * (stakerInfo.stakedAmount / totalDepositAmt)
        // Can't use (stakerInfo.stakedAmount / totalDepositAmt) because it might return 0
        return ((block.number - stakerInfo.blockNum) * REWARD_PER_BLOCK * stakerInfo.stakedAmount) / totalDepositAmt;
    }

    function unstake() external nonReentrant {
        uint256 reward = calculateReward(msg.sender);

        totalDepositAmt -= stakes[msg.sender].stakedAmount;
        uint256 withDrawAmount = stakes[msg.sender].stakedAmount + reward / (10 ** 18);
        delete stakes[msg.sender];

        token.transfer(msg.sender, withDrawAmount);
        // Emit event
        emit Unstaked(msg.sender, withDrawAmount);
    }
}