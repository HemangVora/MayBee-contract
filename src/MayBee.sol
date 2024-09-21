// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MayBee {
    struct Market {
        string description;
        uint256 expirationDate;
        uint256 yesShares;
        uint256 noShares;
        bool isResolved;
        bool outcome;
        address admin;
    }

    mapping(uint256 => Market) public markets;
    mapping(uint256 => mapping(address => uint256)) public userYesShares;
    mapping(uint256 => mapping(address => uint256)) public userNoShares;

    uint256 public marketCount;

    event MarketCreated(
        uint256 marketId,
        string description,
        uint256 expirationDate
    );
    event BetPlaced(uint256 marketId, address user, bool isYes, uint256 amount);
    event MarketResolved(uint256 marketId, bool outcome);

    modifier onlyAdmin(uint256 _marketId) {
        require(
            msg.sender == markets[_marketId].admin,
            "Only admin can perform this action"
        );
        _;
    }

    modifier marketOpen(uint256 _marketId) {
        require(!markets[_marketId].isResolved, "Market is already resolved");
        require(
            block.timestamp < markets[_marketId].expirationDate,
            "Market has expired"
        );
        _;
    }

    function createMarket(
        string memory _description,
        uint256 _expirationDate
    ) external {
        require(
            _expirationDate > block.timestamp,
            "Expiration date must be in the future"
        );

        marketCount++;
        markets[marketCount] = Market({
            description: _description,
            expirationDate: _expirationDate,
            yesShares: 0,
            noShares: 0,
            isResolved: false,
            outcome: false,
            admin: msg.sender
        });

        emit MarketCreated(marketCount, _description, _expirationDate);
    }

    function placeBet(
        uint256 _marketId,
        bool _isYes
    ) external payable marketOpen(_marketId) {
        require(msg.value > 0, "Bet amount must be greater than 0");

        if (_isYes) {
            markets[_marketId].yesShares += msg.value;
            userYesShares[_marketId][msg.sender] += msg.value;
        } else {
            markets[_marketId].noShares += msg.value;
            userNoShares[_marketId][msg.sender] += msg.value;
        }

        emit BetPlaced(_marketId, msg.sender, _isYes, msg.value);
    }

    function resolveMarket(
        uint256 _marketId,
        bool _outcome
    ) external onlyAdmin(_marketId) {
        require(!markets[_marketId].isResolved, "Market is already resolved");

        markets[_marketId].isResolved = true;
        markets[_marketId].outcome = _outcome;

        emit MarketResolved(_marketId, _outcome);
    }

    function claimRewards(uint256 _marketId) external {
        Market storage market = markets[_marketId];
        require(market.isResolved, "Market is not resolved yet");

        uint256 reward = 0;
        if (market.outcome && userYesShares[_marketId][msg.sender] > 0) {
            reward =
                (userYesShares[_marketId][msg.sender] *
                    (market.yesShares + market.noShares)) /
                market.yesShares;
            userYesShares[_marketId][msg.sender] = 0;
        } else if (!market.outcome && userNoShares[_marketId][msg.sender] > 0) {
            reward =
                (userNoShares[_marketId][msg.sender] *
                    (market.yesShares + market.noShares)) /
                market.noShares;
            userNoShares[_marketId][msg.sender] = 0;
        }

        require(reward > 0, "No rewards to claim");
        payable(msg.sender).transfer(reward);
    }

    function getMarketInfo(
        uint256 _marketId
    )
        external
        view
        returns (
            string memory description,
            uint256 expirationDate,
            uint256 yesShares,
            uint256 noShares,
            bool isResolved,
            bool outcome
        )
    {
        Market storage market = markets[_marketId];
        return (
            market.description,
            market.expirationDate,
            market.yesShares,
            market.noShares,
            market.isResolved,
            market.outcome
        );
    }
}
