// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SafeTransferLib, ERC20} from "solmate/utils/SafeTransferLib.sol";
import {IERC20} from "src/interfaces/IERC20.sol";

contract DefiSwap {
    // immutables: no SLOAD
    address public immutable tokenA;
    address public immutable tokenB;

    // storage
    uint256 public k;

    // errors
    error NotSupported();

    constructor(address _tokenA, address _tokenB) {
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    function addLiquidity(uint256 _amtA, uint256 _amtB) public returns (bool) {
        // Get current amounts
        uint256 currentAmtA = IERC20(tokenA).balanceOf(address(this));
        uint256 currentAmtB = IERC20(tokenB).balanceOf(address(this));

        // Update pricing model
        uint256 newAmtA = currentAmtA + _amtA;
        uint256 newAmtB = currentAmtB + _amtB;
        k = newAmtA * newAmtB;

        // Transfer new liquidity from user
        SafeTransferLib.safeTransferFrom(ERC20(tokenA), msg.sender, address(this), _amtA);
        SafeTransferLib.safeTransferFrom(ERC20(tokenB), msg.sender, address(this), _amtB);

        return true;
    }

    function swapExactInput(address _inputToken, address _outputToken, uint256 _inAmt) public returns (bool) {
        // input validation
        if (_inputToken != tokenA && _inputToken != tokenB) revert NotSupported();
        if (_outputToken != tokenA && _outputToken != tokenB) revert NotSupported();

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
