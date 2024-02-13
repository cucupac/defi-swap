// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {DefiSwap} from "src/DefiSwap.sol";
import {IERC20} from "src/interfaces/IERC20.sol";
import {DAI, UNI} from "test/common/constants.t.sol";

contract DefiSwapTest is Test {
    // contracts
    DefiSwap public defiSwap;

    // storage
    struct TokenBalances {
        uint256 preXBal;
        uint256 preYBal;
        uint256 postXBal;
        uint256 postYBal;
    }

    function setUp() public {
        defiSwap = new DefiSwap(DAI, UNI);
    }

    function test_addLiquidityFirstTime(uint256 _xAmt, uint256 _yAmt) public {
        // bound fuzzed variables
        _xAmt = bound(_xAmt, 1e18 * 100, 1e18 * 10_000);
        _yAmt = bound(_yAmt, 1e18 * 100, 1e18 * 10_000);

        // setup
        TokenBalances memory tokenBals;
        deal(DAI, address(this), _xAmt);
        deal(UNI, address(this), _yAmt);

        // approve
        IERC20(DAI).approve(address(defiSwap), _xAmt);
        IERC20(UNI).approve(address(defiSwap), _yAmt);

        // pre-act data
        tokenBals.preXBal = IERC20(DAI).balanceOf(address(defiSwap));
        tokenBals.preYBal = IERC20(UNI).balanceOf(address(defiSwap));
        uint256 k = defiSwap.k();

        // assertions
        assertEq(tokenBals.postXBal, 0);
        assertEq(tokenBals.postYBal, 0);
        assertEq(k, 0);

        // act
        defiSwap.addLiquidity(_xAmt, _yAmt);

        // pre-act data
        tokenBals.postXBal = IERC20(DAI).balanceOf(address(defiSwap));
        tokenBals.postYBal = IERC20(UNI).balanceOf(address(defiSwap));
        k = defiSwap.k();

        // assertions
        assertEq(tokenBals.postXBal, _xAmt);
        assertEq(tokenBals.postYBal, _yAmt);
        assertEq(k, _xAmt * _yAmt);
    }

    function test_addLiquiditySubsequently(uint256 _xAmt, uint256 _yAmt) public {
        // setup 1: add liquidity
        uint256 firstXAmt = 1e18 * 1_000;
        uint256 firstYAmt = 1e18 * 1_000;
        deal(DAI, address(this), firstXAmt);
        deal(UNI, address(this), firstYAmt);
        IERC20(DAI).approve(address(defiSwap), firstXAmt);
        IERC20(UNI).approve(address(defiSwap), firstYAmt);
        defiSwap.addLiquidity(firstXAmt, firstYAmt);

        // pre-act data
        TokenBalances memory tokenBals;
        uint256 k = defiSwap.k();
        tokenBals.preXBal = IERC20(DAI).balanceOf(address(defiSwap));
        tokenBals.preYBal = IERC20(UNI).balanceOf(address(defiSwap));

        // bound fuzzed variables
        _xAmt = bound(_xAmt, 1e6 * 100, 1e6 * 10_000);
        _yAmt = bound(_yAmt, 1e6 * 100, 1e6 * 10_000);

        // setup 2: add liquidity again
        deal(DAI, address(this), _xAmt);
        deal(UNI, address(this), _yAmt);
        IERC20(DAI).approve(address(defiSwap), _xAmt);
        IERC20(UNI).approve(address(defiSwap), _yAmt);

        // act
        defiSwap.addLiquidity(_xAmt, _yAmt);

        // post-act data
        uint256 newK = defiSwap.k();
        tokenBals.postXBal = IERC20(DAI).balanceOf(address(defiSwap));
        tokenBals.postYBal = IERC20(UNI).balanceOf(address(defiSwap));

        assertEq(tokenBals.postXBal, tokenBals.preXBal + _xAmt);
        assertEq(tokenBals.postYBal, tokenBals.preYBal + _yAmt);
        assertGt(newK, k);
        assertEq(newK, tokenBals.postXBal * tokenBals.postYBal);
    }

    function test_SwapExactInput(uint256 _xAmt) public {
        // setup 1: add liquidity
        uint256 firstXAmt = 1e18 * 1_000;
        uint256 firstYAmt = 1e18 * 1_000;
        deal(DAI, address(this), firstXAmt);
        deal(UNI, address(this), firstYAmt);
        IERC20(DAI).approve(address(defiSwap), firstXAmt);
        IERC20(UNI).approve(address(defiSwap), firstYAmt);
        defiSwap.addLiquidity(firstXAmt, firstYAmt);

        // bound fuzzed variables
        _xAmt = bound(_xAmt, 1e18 * 1, 1e18 * 900);

        // fund this contract with input token
        deal(DAI, address(this), _xAmt);
        IERC20(DAI).approve(address(defiSwap), _xAmt);

        // expecations
        uint256 k = defiSwap.k();
        uint256 newXAmt = firstXAmt + _xAmt;
        uint256 yPrime = k / newXAmt;
        uint256 expectedYAmt = firstYAmt - yPrime;

        // pre-act data
        TokenBalances memory tokenBals;
        tokenBals.preXBal = IERC20(DAI).balanceOf(address(defiSwap));
        tokenBals.preYBal = IERC20(UNI).balanceOf(address(defiSwap));
        uint256 userXAmt = IERC20(DAI).balanceOf(address(this));
        uint256 userYAmt = IERC20(UNI).balanceOf(address(this));
        assertEq(userYAmt, 0);
        assertEq(userXAmt, _xAmt);

        // act
        defiSwap.swapExactInput(DAI, UNI, _xAmt);

        // post-act data
        userYAmt = IERC20(UNI).balanceOf(address(this));
        userXAmt = IERC20(DAI).balanceOf(address(this));
        tokenBals.postXBal = IERC20(DAI).balanceOf(address(defiSwap));
        tokenBals.postYBal = IERC20(UNI).balanceOf(address(defiSwap));

        // assertions
        assertEq(userYAmt, expectedYAmt);
        assertEq(userXAmt, 0);
        assertEq(tokenBals.postXBal, tokenBals.preXBal + _xAmt);
        assertEq(tokenBals.postYBal, tokenBals.preYBal - userYAmt);
        assertApproxEqRel(k, tokenBals.postXBal * tokenBals.postYBal, 1);
    }
}
