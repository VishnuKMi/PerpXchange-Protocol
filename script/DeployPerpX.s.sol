// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {PerpXchange} from "../src/PerpXchange.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/Test.sol";

contract DeployPerpX is Script {
    function run() external returns (PerpXchange, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (address priceFeed, address usdc) = helperConfig.activeNetworkConfig();
        console.log("Price feed address: %s", priceFeed);
        console.log("USDC address: %s", (usdc));

        vm.startBroadcast();
        PerpXchange perpXchange = new PerpXchange(priceFeed, IERC20(usdc));
        vm.stopBroadcast();

        return (perpXchange, helperConfig);
    }
}
