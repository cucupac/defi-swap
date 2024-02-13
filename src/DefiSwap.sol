// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {SafeTransferLib, ERC20} from "solmate/utils/SafeTransferLib.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

contract DefiSwap {
    // immutables: no SLOAD
    address public immutable tokenX;
    address public immutable tokenY;

    // storage
    uint256 public k;

    // errors
    error NotSupported();

    constructor(address _tokenX, address _tokenY) {
        tokenX = _tokenX;
        tokenY = _tokenY;
    }

    function addLiquidity(uint256 _amtX, uint256 _amtY) public returns (bool) {
        // Get current amounts
        uint256 currentAmtX = IERC20(tokenX).balanceOf(address(this));
        uint256 currentAmtY = IERC20(tokenY).balanceOf(address(this));

        // Update pricing model
        uint256 newAmtX = currentAmtX + _amtX;
        uint256 newAmtY = currentAmtY + _amtY;
        k = newAmtX * newAmtY;

        // Transfer new liquidity from user
        SafeTransferLib.safeTransferFrom(ERC20(tokenX), msg.sender, address(this), _amtX);
        SafeTransferLib.safeTransferFrom(ERC20(tokenY), msg.sender, address(this), _amtY);

        return true;
    }

    function swapExactInput(address _inputToken, address _outputToken, uint256 _inAmt) public returns (bool) {
        // input validation
        if (_inputToken != tokenX && _inputToken != tokenY) revert NotSupported();
        if (_outputToken != tokenX && _outputToken != tokenY) revert NotSupported();

        // get current amounts
        uint256 preXAmt = IERC20(_inputToken).balanceOf(address(this));
        uint256 preYAmt = IERC20(_outputToken).balanceOf(address(this));

        // calculate y token amount
        uint256 newXAmt = preXAmt + _inAmt;
        uint256 yPrime = k / newXAmt;
        uint256 outAmt = preYAmt - yPrime;

        // transfer input token to contract
        SafeTransferLib.safeTransferFrom(ERC20(_inputToken), msg.sender, address(this), _inAmt);

        // transfer output token to user
        SafeTransferLib.safeTransfer(ERC20(_outputToken), msg.sender, outAmt);

        return true;
    }
}
