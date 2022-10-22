// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.7.0 <0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LotteryToken} from "./Token.sol";

contract Lottery is Ownable {
    LotteryToken public paymentToken;
    uint256 public closingTime;
    bool public betsOpen;
    uint256 public betPrice;
    uint256 public betFee;

    /// @notice Amount of tokens in the prize pool
    uint256 public prizePool;
    /// @notice Amount of tokens in the ownerPool
    uint256 public ownerPool;

    /// @notice Mapping of prize available for withdraw for each account
    mapping(address => uint256) public prize;

    /// @dev List of bet slots
    address[] _slots;

    constructor(
        string memory name,
        string memory symbol,
        uint256 _betPrice,
        uint256 _betFee
    ) {
        paymentToken = new LotteryToken(name, symbol);
        betPrice = _betPrice;
        betFee = _betFee;
    }

    modifier whenBetsClosed() {
        require(!betsOpen, "Lottery: Bets are note closed");
        _;
    }
    modifier whenBetsOpen() {
        require(
            betsOpen && block.timestamp < closingTime,
            "Lottery: Bets are closed"
        );
        _;
    }

    /// @dev _closingTime target time in seconds expressed in epoch time for the bets to close
    function openBets(uint256 _closingTime) public onlyOwner whenBetsClosed {
        require(
            _closingTime > block.timestamp,
            "Lottery: Closing time must be in the future"
        );
        closingTime = _closingTime;
        betsOpen = true;
    }

    function purchaseTokens() public payable {
        paymentToken.mint(msg.sender, msg.value);
    }

    function bet() public whenBetsOpen {
        ownerPool += betFee;
        prizePool += betPrice;
        _slots.push(msg.sender);
        paymentToken.transferFrom(msg.sender, address(this), betPrice + betFee);
    }

    function betMany(uint256 times) public {
        require(times > 0);
        while (times > 0) {
            bet();
            times--;
        }
    }

    function closeLottery() public {
        require(
            block.timestamp >= closingTime,
            "Lottery: Too soon to be closed"
        );
        require(betsOpen, "Lottery: Already closed");
        if (_slots.length > 0) {
            uint256 winnerIndex = getRandomNumber() % _slots.length;
            address winner = _slots[winnerIndex];
            prize[winner] += prizePool;
            prizePool = 0;
            delete (_slots);
        }
        betsOpen = false;
    }

    function getRandomNumber() public view returns (uint256 randomNumber) {
        randomNumber = block.difficulty;
    }

    function prizeWithdraw(uint256 amount) public {
        require(amount <= ownerPool, "Not enough prize");
        ownerPool -= amount;
        paymentToken.transfer(msg.sender, amount);
    }

    function ownerWithdraw(uint256 amount) public onlyOwner {
        require(amount <= prize[msg.sender], "Not enough prize");
        prize[msg.sender] -= amount;
        paymentToken.transfer(msg.sender, amount);
    }

    function returnsTokens(uint256 amount) public {
        paymentToken.burnFrom(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }
}
