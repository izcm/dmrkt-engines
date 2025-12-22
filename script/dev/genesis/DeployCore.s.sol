// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// local
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {OrderEngine} from "orderbook/OrderEngine.sol";
import {DMrktGremlin as DNFT} from "nfts/DMrktGremlin.ERC721.sol";

contract DeployCore is BaseDevScript, Config {
    OrderEngine public orderEngine;

    function run() external {
        // --------------------------------
        // PHASE 0: LOAD CONFIG
        // --------------------------------
        _loadConfig("deployments.toml", true);

        logSection("LOAD CONFIG");

        uint256 chainId = block.chainid;

        console.log("ChainId: %s", chainId);

        address weth = config.get("weth").toAddress();
        uint256 funderPk = uint256(uint256(vm.envUint("PRIVATE_KEY")));

        // --------------------------------
        // PHASE 1: DEPLOY MARKETPLCE & NFTS
        // --------------------------------
        logSection("DEPLOY CORE CONTRACTS");

        // since the script uses the same private key its not necessary but I like to be explicit
        vm.startBroadcast(funderPk);

        orderEngine = new OrderEngine(weth, msg.sender);
        DNFT dNft = new DNFT();

        vm.stopBroadcast();

        logDeployment("OrderEngine", address(orderEngine));
        logDeployment("DNFT", address(dNft));

        // ---  write deployed addrs to .toml ---

        // marketplace logic
        config.set("verifying_contract", address(orderEngine)); // for our order builder
        config.set("marketplace", address(orderEngine)); // nft bootstrap

        // nft contracts
        config.set("dmrktgremlin", address(dNft));
    }
}
