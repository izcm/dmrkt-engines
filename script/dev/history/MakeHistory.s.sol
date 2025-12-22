// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// local
import {BaseDevScript} from "dev/BaseDevScript.s.sol";

// core libraries
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// periphery libraries
import {OrderBuilder} from "periphery/builders/OrderBuilder.sol";

contract MakeHistory is BaseDevScript, Config {
    uint256 internal HISTORY_START_TS;

    // read how to read/write arrays in deployments.toml
    // then have this as a collection[] loop over each collection
    address internal collection;

    function setUp() internal returns (address) {
        // --------------------------------
        // PHASE 0: LOAD CONFIG
        // --------------------------------
        _loadConfig("deployments.toml", true);

        logSection("LOAD CONFIG");

        uint256 chainId = block.chainid;

        console.log("ChainId: %s", chainId);

        // read .env
        HISTORY_START_TS = vm.envUint("HISTORY_START_TS");

        // read deployments.toml
        collection = config.get("dmrktgremlin").toAddress();

        // collections.push(config.get("dmrktgremlin").toAddress());
        // collections.push(config.get("kitz_erc721").toAddress());
        // collections.push(config.get("whatever_next").toAddress());
    }

    function runWeek(uint256 weekIdx) external {
        setUp();
        _jumpToWeek(weekIdx);
        _createAsks(collection);
    }

    function finalize() external {
        setUp();
        _jumpToNow();
    }

    // takes param to futureproof since there soon will be multiple collections
    function _createAsks(address collection) internal {
        // to make the orders ¨tokenId's differ from the `OrderBuilder`
        // see BuildOrders makeDigest function => move it to basedevscript
    }

    // --------------------------------
    // INTERNAL TIME HELPERS
    // --------------------------------

    function _jumpToWeek(uint256 weekIndex) internal {
        // weekIndex = 0,1,2,3
        vm.warp(HISTORY_START_TS + (weekIndex * 7 days));
    }

    function _jumpToNow() internal {
        vm.warp(vm.envUint("NOW_TS"));
    }
}
