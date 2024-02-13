// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "./CommitReveal.sol";

contract RPS is CommitReveal {
    struct Player {
        uint256 choice; // 0 - Rock, 1 - Paper , 2 - Scissors, 3 - undefined
        address addr;
        uint256 fund;
    }

    uint256 public constant TIMEOUT = 10 seconds;

    mapping(uint256 => Player) public player;
    mapping(address => uint256) public playerIdx;
 
    uint256 public numPlayer = 0;
    uint256 public reward = 0;
    uint256 public numCommit = 0;
    uint256 public numRevealed = 0;
    uint256 public latestActionTimestamp = 0;

    function addPlayer() public payable {
        require(numPlayer < 2);
        require(msg.value == 1 ether);

        reward += msg.value;
        player[numPlayer].fund = msg.value;
        player[numPlayer].addr = msg.sender;
        player[numPlayer].choice = 3;
        playerIdx[msg.sender] = numPlayer;
        numPlayer++;

        latestActionTimestamp = block.timestamp;
    }

    function getChoiceHash(uint256 choice, uint256 salt)
        public
        view
        returns (bytes32)
    {
        return getSaltedHash(bytes32(choice), bytes32(salt));
    }

    function commitChoice(bytes32 choiceHash) public {
        require(numPlayer == 2);
        require(msg.sender == player[playerIdx[msg.sender]].addr);
        require(choiceHash != 0);

        commit(choiceHash);

        numCommit++;

        latestActionTimestamp = block.timestamp;
    }

    function revealChoice(uint256 choice, uint256 salt) public {
        require(choice <= 3);
        require(numPlayer == 2);
        require(numCommit == 2);
        require(msg.sender == player[playerIdx[msg.sender]].addr);

        revealAnswer(bytes32(choice), bytes32(salt));
        player[playerIdx[msg.sender]].choice = choice;

        numRevealed++;

        if (numRevealed == 2) {
            _checkWinnerAndPay();
        }

        latestActionTimestamp = block.timestamp;
    }

    function _checkWinnerAndPay() private {
        uint256 p0Choice = player[0].choice;
        uint256 p1Choice = player[1].choice;
        address payable account0 = payable(player[0].addr);
        address payable account1 = payable(player[1].addr);
        if ((p0Choice + 1) % 3 == p1Choice) {
            account1.transfer(reward);
        } else if ((p1Choice + 1) % 3 == p0Choice) {
            account0.transfer(reward);
        } else {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }

        latestActionTimestamp = block.timestamp;
        _reset();
    }
    
    function currentTime() public view returns(uint256) {
        return block.timestamp;
    } 

    function checkTimeout() public {
        require(block.timestamp > latestActionTimestamp + TIMEOUT , "Time has not ran out yet");
        require(msg.sender == player[0].addr || msg.sender == player[1].addr);
        require(numPlayer > 0);
        require(reward > 0);

        address payable account0 = payable(player[0].addr);
        address payable account1 = payable(player[1].addr);

        // Refund to first player if [number of player is not enough]
        if (numPlayer < 2) {
            account0.transfer(reward);
            
            _reset();
            return;
        }
        
        require(numPlayer == 2);
        
        // Refund to all player if [any player doesn't commit in time]
        if (
            numCommit < 2 &&
            (commits[account0].commit == 0 || commits[account1].commit == 0)
        ) {
            account0.transfer(player[0].fund);
            account1.transfer(player[1].fund);
            
            _reset();
            return;
        }

        // Punish if [a player doesn't reveal in time]
        if (commits[account0].revealed && !commits[account1].revealed) {
            account0.transfer(reward);
            
            _reset();
            return;
        } else if (commits[account1].revealed && !commits[account0].revealed) {
            account1.transfer(reward);
            
            _reset();
            return;
        }
    }

    function _reset() private {
        numPlayer = 0;
        reward = 0;
        numCommit = 0;
        numRevealed = 0;
        latestActionTimestamp = 0;
    }
}
