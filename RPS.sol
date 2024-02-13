// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "./CommitReveal.sol";

contract RPS is CommitReveal {
    struct Player {
        uint choice; // 0 - Rock, 1 - Paper , 2 - Scissors, 3 - undefined
        address addr;
    }
    
    mapping (uint => Player) public player;
    mapping (address => uint) public playerIdx;
    uint public numPlayer = 0;
    uint public reward = 0;
    uint public numInput = 0;
    uint public numRevealed = 0;

    function addPlayer() public payable {
        require(numPlayer < 2);
        require(msg.value == 1 ether);

        reward += msg.value;
        player[numPlayer].addr = msg.sender;
        player[numPlayer].choice = 3;
        playerIdx[msg.sender] = numPlayer;
        numPlayer++;
    }

    function getChoiceHash(uint choice, uint salt) public view returns(bytes32) {
        return getSaltedHash(bytes32(choice), bytes32(salt));
    }

    function commitChoice(bytes32 choiceHash) public  {
        require(numPlayer == 2);
        require(msg.sender == player[playerIdx[msg.sender]].addr);
        require(choiceHash != 0);

        commit(choiceHash);
 
        numInput++;
    }

    function revealChoice(uint choice, uint salt) public {
        require(choice <= 3);
        require(numPlayer == 2);
        require(numInput == 2);
        require(msg.sender == player[playerIdx[msg.sender]].addr);

        revealAnswer(bytes32(choice), bytes32(salt));
        player[playerIdx[msg.sender]].choice = choice;

        numRevealed++;

        if (numRevealed == 2) {
            _checkWinnerAndPay();
        }
    }

    function _checkWinnerAndPay() private {
        uint p0Choice = player[0].choice;
        uint p1Choice = player[1].choice;
        address payable account0 = payable(player[0].addr);
        address payable account1 = payable(player[1].addr);
        if ((p0Choice + 1) % 3 == p1Choice) {
            // to pay player[1]
            account1.transfer(reward);
        }
        else if ((p1Choice + 1) % 3 == p0Choice) {
            // to pay player[0]
            account0.transfer(reward);    
        }
        else {
            // to split reward
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        }
    }
}
