// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// local contracts
import {OrderEngine} from "orderbook/OrderEngine.sol";

// TODO: cryptopunk is not erc721 compatible, wrapper?
interface IERC721 {
    function setApprovalForAll(address operator, bool approved) external;
    function ownerOf(uint256 tokenId) external;
}

contract Setup is Script, Config, Test {
    OrderEngine public orderEngine;

    function run() external {
        _loadConfig("deployments.toml", true);

        uint256 chainId = block.chainid;
        console.log("Deploying to chain: %s", chainId);

        // config addresses
        address bayc = config.get("bayc").toAddress();
        console.log(bayc);

        vm.startBroadcast();
        orderEngine = new OrderEngine();
        vm.stopBroadcast();

        console.log("\nEngine Deployed: %s", address(orderEngine));
        console.logAddress(address(orderEngine));

        console.log("\nDeployment complete! Addresses saved to deployments.toml");
    }

    function readOwnerOf(address tokenContract, uint256 tokenId) internal {
        IERC721(tokenContract).ownerOf(tokenId);
        console.log("Owner of token %s", tokenId);
    }
}
