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

interface IUSDC {
    function balanceOf(address account) external view returns (uint256);

    function mint(address to, uint256 amount) external;

    function configureMinter(address minter, uint256 minterAllowedAmount) external;

    function masterMinter() external view returns (address);

    function approve(address spender, uint256 amount) external returns (bool);
}

contract PerpXchangeTest is Test, IPerpXchange {
    PerpXchange public perpXchange;
    HelperConfig public helperConfig;
    DeployPerpX public deployer;
    address public priceFeed;
    address public USER = makeAddr("USER");
    address public USER2 = makeAddr("USER2");
    address public LP = makeAddr("LP");

    // USDC contract address on mainnet
    address usdc;
    // User mock params
    uint256 SIZE = 1;
    uint256 SIZE_2 = 2;
    uint256 COLLATERAL = 10000e6; // sufficient collateral to open a position with size 1
    uint256 DECREASE_COLLATERAL = 1500e6;
    // LP mock params
    uint256 LIQUIDITY = 1000000e6;

    uint256 private constant MAX_UTILIZATION_PERCENTAGE = 80; //80%
    uint256 private constant MAX_UTILIZATION_PERCENTAGE_DECIMALS = 100;
    uint256 private constant SECONDS_PER_YEAR = 31536000; // 365 * 24 * 60 * 60
    uint256 private constant BORROWING_RATE = 10;
    uint256 private constant DECIMALS_DELTA = 1e12; // btc decimals - usdc decimals
    uint256 private constant DECIMALS_PRECISION = 1e4;

    uint256 s_totalLiquidityDeposited;

    // Dead Shares
    uint256 DEAD_SHARES = 1000;

    function setUp() external {
        deployer = new DeployPerpX();
        (perpXchange, helperConfig) = deployer.run();
        (priceFeed, usdc) = helperConfig.activeNetworkConfig();

        // MAINNET SETUP

        // spoof.configureMinter() call with the master minter account
        vm.prank(IUSDC(usdc).masterMinter());
        // allow this test contract to mint USDC
        IUSDC(usdc).configureMinter(address(this), type(uint256).max);
        // mint max to the test contract (or an external user)
        IUSDC(usdc).mint(USER, COLLATERAL);
        IUSDC(usdc).mint(USER2, COLLATERAL);
        // mint max to the LP account
        IUSDC(usdc).mint(LP, LIQUIDITY);
        deployer = new DeployPerpX();
        (perpXchange, helperConfig) = deployer.run();
        (priceFeed,) = helperConfig.activeNetworkConfig(); // @follow-up why not 'usdc' ?

        vm.prank(USER);
        IERC20(usdc).approve(address(perpXchange), type(uint256).max);
        vm.prank(USER2);
        IERC20(usdc).approve(address(perpXchange), type(uint256).max);
        vm.prank(LP);
        IERC20(usdc).approve(address(perpXchange), type(uint256).max);
    }

    /// MODIFIERS ///

    modifier addLiquidity(uint256 amount) {
        vm.startPrank(LP);
        IERC20(usdc).approve(address(perpXchange), type(uint256).max); //@follow-up do we need separate approval for LP here than the on in 'setUp()' ?
        perpXchange.deposit(amount, LP);
        vm.stopPrank();
        _;
    }

    modifier addCollateral(uint256 amount) {
        vm.prank(USER);
        perpXchange.depositCollateral(amount);
        _;
    }

    modifier depositCollateralOpenLongPosition(uint256 amount) {
        vm.startPrank(USER);
        perpXchange.depositCollateral(amount);
        perpXchange.createPosition(SIZE, true);
        vm.stopPrank();
        _;
    }

    modifier longPositionOpened(uint256 liquidity, uint256 amount, uint256 size) {
        vm.prank(LP);
        perpXchange.deposit(liquidity, LP);

        vm.startPrank(USER);
        perpXchange.depositCollateral(amount);
        perpXchange.createPosition(size, true);
        vm.stopPrank();
        _;
    }

    /**
     * @dev     This mimics the share calculation behaviour in ERC4626
     */
    function shareCalculation(uint256 assets) public view returns (uint256 withdrawShares) {
        withdrawShares =
            Math.mulDiv(assets, perpXchange.totalSupply() + 10 ** 0, perpXchange.totalAssets() + 1, Math.Rounding.Floor);
    }

    /// LIQUIDITY PROVIDERS ///
}
