// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "./CommitReveal.sol";

contract RPS is CommitReveal {
    enum Choice { Rock, Water, Air, Paper, Sponge, Scissors, Fire }

    struct Player {
        Choice choice;
        address addr;
        uint256 fund;
    }

    uint256 public constant TIMEOUT = 1 days;

    mapping(uint256 => Player) public player;
    mapping(address => uint256) public playerIdx;
 
    uint256 public numPlayer = 0;
    uint256 public reward = 0;
    uint256 public numCommit = 0;
    uint256 public numRevealed = 0;
    uint256 public latestActionTimestamp = 0;

    function addPlayer() public payable {
        require(numPlayer < 2, "Maximum number of players reached");
        require(msg.value == 1 ether, "Insufficient or excessive amount sent");

        reward += msg.value;
        player[numPlayer].fund = msg.value;
        player[numPlayer].addr = msg.sender;
        playerIdx[msg.sender] = numPlayer;
        numPlayer++;

        latestActionTimestamp = block.timestamp;
    }

    function getChoiceHash(Choice choice, uint256 salt)
        public
        view
        returns (bytes32)
    {
        require(uint256(choice) <= 6, "Invalid choice");
        return getSaltedHash(bytes32(uint256(choice)), bytes32(salt));
    }

    function commitChoice(bytes32 choiceHash) public {
        require(choiceHash != 0, "Invalid choice hash");
        require(numPlayer == 2, "Not enough players");
        require(msg.sender == player[playerIdx[msg.sender]].addr, "Invalid sender");
        require(commits[msg.sender].commit == 0, "Already committed");
        require(!commits[msg.sender].revealed, "Already revealed");

        commit(choiceHash);

        numCommit++;

        latestActionTimestamp = block.timestamp;
    }

    function revealChoice(Choice choice, uint256 salt) public {
        require(uint256(choice) <= 6, "Invalid choice");
        require(numPlayer == 2, "Not enough players");
        require(numCommit == 2, "Not all players have committed");
        require(msg.sender == player[playerIdx[msg.sender]].addr, "Invalid sender");


        revealAnswer(bytes32(uint256(choice)), bytes32(salt));
        player[playerIdx[msg.sender]].choice = choice;

        numRevealed++;

        if (numRevealed == 2) {
            _checkWinnerAndPay();
        }

        latestActionTimestamp = block.timestamp;
    }

    function _checkWinnerAndPay() private {
        uint256 p0Choice = uint256(player[0].choice);
        uint256 p1Choice = uint256(player[1].choice);
        address payable account0 = payable(player[0].addr);
        address payable account1 = payable(player[1].addr);

        if ((p0Choice + 1) % 7 == p1Choice || (p0Choice + 2) % 7 == p1Choice || (p0Choice + 3) % 7 == p1Choice) {
            account1.transfer(reward);
        } else if ((p1Choice + 1) % 7 == p0Choice || (p1Choice + 2) % 7 == p0Choice || (p1Choice + 3) % 7 == p0Choice) {
            account0.transfer(reward);
        } else {
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }

        _reset();
    }
    

    function checkTimeout() public {
        require(block.timestamp > latestActionTimestamp + TIMEOUT, "Timeout has not occurred yet");
        require(msg.sender == player[0].addr || msg.sender == player[1].addr, "Invalid sender");
        require(numPlayer > 0, "No players registered");


        address payable account0 = payable(player[0].addr);

        // Refund to first player if [number of player is not enough]
        if (numPlayer < 2) {
            account0.transfer(reward);
            
            _reset();
            return;
        }

        address payable account1 = payable(player[1].addr);
        
        // Refund to all player if [any player doesn't commit in time] or [all players commit but not reveal]
        if (numCommit < 2 || numRevealed == 0) {
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
        player[0] = Player(Choice(0), address(0), 0);
        player[1] = Player(Choice(0), address(0), 0);
    }
}
