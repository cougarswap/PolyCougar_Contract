// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./libs/SafeBEP20.sol";

/**
 * @dev CougarLocker contract locks the liquidity (LP tokens) which are added by the automatic liquidity acquisition
 * function in CougarToken.
 *
 * The owner of CougarLocker will be transferred to the timelock once the contract deployed.
 * 
 * Q: Why don't we just burn the liquidity or lock the liquidity on other platforms?
 * A: If there is an upgrade of CougarSwap AMM, we can migrate the liquidity to our new version exchange.
 *
 */

contract CougarLocker is Ownable {
    using SafeBEP20 for IBEP20;

    event Unlocked(address indexed token, address indexed recipient, uint256 amount);

    function unlock(IBEP20 _token, address _recipient) public onlyOwner {
        require(_recipient != address(0), "CougarLocker::unlock: ZERO address.");

        uint256 amount = _token.balanceOf(address(this));
        _token.safeTransfer(_recipient, amount);
        emit Unlocked(address(_token), _recipient, amount);
    }
}