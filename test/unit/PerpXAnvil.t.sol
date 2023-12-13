// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {IPerpXchange} from "../../src/IPerpXchange.sol";
import {PerpXchange} from "../../src/PerpXchange.sol";
import {DeployPerpX} from "../../script/DeployPerpX.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract PerpXTestAnvil is Test, IPerpXchange {
    PerpXchange public perpXchange;
    HelperConfig public helperConfig;
    DeployPerpX public deployer;
    address public priceFeed;
    address public USER = makeAddr("USER");
    address public USER2 = makeAddr("USER2");
    address public LP = makeAddr("LP");

    // USDC contract address from ERC20Mock
    address usdcMock;
    // User mock params
    uint256 SIZE = 1;
    uint256 SIZE_2 = 2;
    uint256 COLLATERAL = 10000e6; // Sufficient collateral to open a position with size 1
    uint256 DECREASE_COLLATERAL = 1500e6;
    // LP mock params
    uint256 LIQUIDITY = 1000000e6;

    uint256 private constant MAX_UTILIZATION_PERCENTAGE = 80; // 80%
    uint256 private constant MAX_UTILIZATION_PERCENTAGE_DECIMALS = 100;
    uint256 private constant SECONDS_PER_YEAR = 31536000; // 365*24*60*60

    uint256 s_totalLiquidityDeposited;

    // Dead Shares
    uint256 DEAD_SHARES = 1000;

    function setUp() external {
        deployer = new DeployPerpX();
        (perpXchange, helperConfig) = deployer.run();
        (priceFeed, usdcMock) = helperConfig.activeNetworkConfig();

        // ANVIL SETUP

        ERC20Mock(usdcMock).mint(USER, COLLATERAL * 1e12);
        ERC20Mock(usdcMock).mint(USER2, COLLATERAL * 1e12);
        ERC20Mock(usdcMock).mint(LP, LIQUIDITY * 1e12);

        vm.prank(USER);
        ERC20Mock(usdcMock).approve(address(perpXchange), type(uint256).max);
        vm.prank(USER2);
        ERC20Mock(usdcMock).approve(address(perpXchange), type(uint256).max);
        vm.prank(LP);
        ERC20Mock(usdcMock).approve(address(perpXchange), type(uint256).max);
    }

    ////////////////////////
    // PnL & Borrowing Fees
    ////////////////////////

    // Needs it own setup
    // forge test --match-test "testUserPnlIncreaseIfBtcPriceIncrease" -vvvv
    function testUserPnlIncreaseIfBtcPriceIncrease() public {
        // setup
        MockV3Aggregator mockV3Aggregator = new MockV3Aggregator(8, 20000 * 1e8);
        PerpXchange perpXBtcIncrease = new PerpXchange(address(mockV3Aggregator), ERC20Mock(usdcMock));

        // Arrange - LP
        vm.startPrank(LP);
        ERC20Mock(usdcMock).approve(address(perpXBtcIncrease), type(uint256).max);
        perpXBtcIncrease.deposit(LIQUIDITY * 1e12, LP);
        vm.stopPrank();

        // Arrange - USER
        vm.startPrank(USER);
        ERC20Mock(usdcMock).approve(address(perpXBtcIncrease), type(uint256).max);
        perpXBtcIncrease.depositCollateral(COLLATERAL * 1e12);
        perpXBtcIncrease.createPosition(SIZE, true);
        uint256 positionId = perpXBtcIncrease.userPositionIdByIndex(USER, 0);
        vm.stopPrank();

        /// BTC price increases from $20_000 to $30_000 ///
        int256 btcUsdcUpdatedPrice = 30000 * 1e8;
        mockV3Aggregator.updateAnswer(btcUsdcUpdatedPrice);
        uint256 currentPrice = perpXBtcIncrease.getPriceFeed(); // 30000 * 1e18

        // Get user's pnl
        int256 userIntPnl = perpXBtcIncrease.getUserPnl(USER); // @follow-up arithmetic-overflow!
        uint256 userPnl = uint256(userIntPnl);
        uint256 expectedPnl = SIZE * (currentPrice - (20000 * 1e18));
        assertEq(userPnl, expectedPnl);

        /// After One year ///
        uint256 currentTimestamp = block.timestamp;
        vm.warp(currentTimestamp + SECONDS_PER_YEAR);

        // Get borrowing fees after a year
        uint256 borrowingFees = perpXBtcIncrease.getBorrowingFees(USER);

        // Get user's pnl
        userIntPnl = perpXBtcIncrease.getUserPnl(USER);
        userPnl = uint256(userIntPnl) - borrowingFees;
        expectedPnl = SIZE * (currentPrice - (20000 * 1e18) - borrowingFees);
        assertEq(userPnl, expectedPnl);

        // Close Position
        vm.startPrank(USER);
        console.log("borrowingFees", borrowingFees);
        perpXBtcIncrease.closePosition(positionId);
        vm.stopPrank();

        uint256 userBalanceAfterClosingPosition = IERC20(usdcMock).balanceOf(USER); // Why not ERC20Mock to wrap usdcMock ?
        console.log("userBalanceAfterClosingPosition", userBalanceAfterClosingPosition);
        uint256 expectedBalanceAfterClosingPosition = COLLATERAL * 1e12 + userPnl;
        assertEq(userBalanceAfterClosingPosition, expectedBalanceAfterClosingPosition);
    }
}
