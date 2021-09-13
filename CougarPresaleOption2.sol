// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";

contract CougarPresaleOption2 is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // The number of unclaimed COUGAR tokens the user has
    mapping(address => uint256) public cougarUnclaimed;
    // Last time user claimed COUGAR
    mapping(address => uint256) public lastCougarClaimed;

    // Addresses that excluded 
    mapping(address => bool) private _whiteList;

    // COUGAR token
    IBEP20 public COUGAR;
    // USDC token
    IBEP20 public USDC;
    // whitelist active
    bool public isWhiteListActive;
    // Sale active
    bool public isSaleActive;
    // Claim active
    bool public isClaimActive;
    // Starting timestamp
    uint256 public startingTimeStamp;
    // Total COUGAR sold
    uint256 public totalCougarSold = 0;

    // Price of presale COUGAR: 0.09 USDC
    uint256 private constant USDCPerCGS = 9;

    // Time per percent
    uint256 private constant timePerPercent = 3600*2;

    // Max Buy Per User
    uint256 public maxBuyPerUser = 45000*(1e6); // decimal 6

    uint256 public firstHarvestTimestamp;

    address payable owner;

    uint256 public constant COUGAR_HARDCAP = 500000*(1e6);

    modifier onlyOwner() {
        require(msg.sender == owner, "You're not the owner");
        _;
    }

    event TokenBuy(address user, uint256 tokens);
    event TokenClaim(address user, uint256 tokens);
    event MaxBuyPerUserUpdated(address user, uint256 previousRate, uint256 newRate);

    constructor(
        address _COUGAR,
        uint256 _startingTimestamp,
        address _usdcAddress
    ) public {
        COUGAR = IBEP20(_COUGAR);
        USDC = IBEP20(_usdcAddress);
        isSaleActive = true;
        isWhiteListActive = false;
        isClaimActive = false;
        owner = msg.sender;
        startingTimeStamp = _startingTimestamp;
    }

    function setWhiteListActive(bool _isWhiteListActive) external onlyOwner {
        isWhiteListActive = _isWhiteListActive;
    }

    function setSaleActive(bool _isSaleActive) external onlyOwner {
        isSaleActive = _isSaleActive;
    }

    function setClaimActive(bool _isClaimActive) external onlyOwner {
        isClaimActive = _isClaimActive;
        if (firstHarvestTimestamp == 0 && _isClaimActive) {
            firstHarvestTimestamp = block.timestamp;
        }
    }

    function buy(uint256 _amount, address _buyer) public nonReentrant {
        require(isSaleActive, "Presale has not started");
        require(
            block.timestamp >= startingTimeStamp,
            "Presale has not started"
        );

        if (isWhiteListActive) {
            require(
            _whiteList[_buyer] == true,
            "You are not a whitelist User"
            );
        }

        address buyer = _buyer;
        uint256 tokens = _amount.div(USDCPerCGS).mul(100);

        require(
            totalCougarSold + tokens <= COUGAR_HARDCAP,
            "Cougar presale hardcap reached"
        );

        require(
            cougarUnclaimed[buyer] + tokens <= maxBuyPerUser,
            "Your amount exceeds the max buy number"
        );

        USDC.safeTransferFrom(buyer, address(this), _amount);

        cougarUnclaimed[buyer] = cougarUnclaimed[buyer].add(tokens);
        totalCougarSold = totalCougarSold.add(tokens);
        emit TokenBuy(buyer, tokens);
    }

    /**
    * @dev Returns the address is whitelist or not.
    */
    function isWhiteList(address _account) public view returns (bool) {
        return _whiteList[_account];
    }

    function claim() external {
        require(isClaimActive, "Claim is not allowed yet");
        require(
            cougarUnclaimed[msg.sender] > 0,
            "User should have unclaimed COUGAR tokens"
        );
        require(
            COUGAR.balanceOf(address(this)) >= cougarUnclaimed[msg.sender],
            "There are not enough COUGAR tokens to transfer."
        );

        if (lastCougarClaimed[msg.sender] == 0) {
            lastCougarClaimed[msg.sender] = firstHarvestTimestamp;
        }

        uint256 allowedPercentToClaim = block
        .timestamp
        .sub(lastCougarClaimed[msg.sender])
        .div(timePerPercent);

        lastCougarClaimed[msg.sender] = block.timestamp;

        if (allowedPercentToClaim > 100) {
            allowedPercentToClaim = 100;
            // ensure they cannot claim more than they have.
        }

        uint256 cougarToClaim = cougarUnclaimed[msg.sender]
        .mul(allowedPercentToClaim)
        .div(100);
        cougarUnclaimed[msg.sender] = cougarUnclaimed[msg.sender].sub(cougarToClaim);

        cougarToClaim = cougarToClaim.mul(1e12);
        COUGAR.safeTransfer(msg.sender, cougarToClaim);
        emit TokenClaim(msg.sender, cougarToClaim);
    }


    function withdrawFunds() external onlyOwner {
        USDC.safeTransfer(msg.sender, USDC.balanceOf(address(this)));
    }

    function withdrawUnsoldCOUGAR() external onlyOwner {
        uint256 amount = COUGAR.balanceOf(address(this)) - totalCougarSold;
        COUGAR.safeTransfer(msg.sender, amount);
    }

    function emergencyWithdraw() external onlyOwner {
        COUGAR.safeTransfer(msg.sender, COUGAR.balanceOf(address(this)));
    }

    /**
    * @dev set whitelist users.
    * Can only be called by the owner.
    */
    function setWhiteList(address _account, bool _value) external onlyOwner {
        _whiteList[_account] = _value;
    }

    function updateMaxBuyPerUser(uint256 _maxBuyPerUser) external onlyOwner {
        require(_maxBuyPerUser <= COUGAR_HARDCAP, "COUGAR::updateMaxBuyPerUser: maxBuyPerUser must not exceed the hardcap.");
        emit MaxBuyPerUserUpdated(msg.sender, maxBuyPerUser, _maxBuyPerUser);
        maxBuyPerUser = _maxBuyPerUser;
    }

}