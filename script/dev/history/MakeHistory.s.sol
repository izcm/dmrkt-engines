// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// core libraries
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// periphery libraries
import {OrderBuilder} from "periphery/builders/OrderBuilder.sol";
import {MarketSim} from "periphery/MarketSim.sol";

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {BaseSettlement} from "dev/BaseSettlement.s.sol";

interface DNFT {
    function MAX_SUPPLY() external view returns (uint256); // out periphery tokens all implement this
}

contract MakeHistory is BaseDevScript, BaseSettlement, Config {
    uint256 internal HISTORY_START_TS;

    address[] internal collections;

    mapping(address => uint256[]) colletionSelected;

    function setUp() internal {
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
        address marketplace = config.get("marketplace").toAddress();
        address weth = config.get("weth").toAddress();

        collections.push(config.get("dmrktgremlin").toAddress());

        _initBaseSettlement(marketplace, weth);

        // collections.push(config.get("dmrktgremlin").toAddress());
        // collections.push(config.get("kitz_erc721").toAddress());
        // collections.push(config.get("whatever_next").toAddress());
    }

    function runWeek(uint256 weekIdx) external {
        setUp();
        _jumpToWeek(weekIdx);
        _initOrders(weekIdx);
    }

    function finalize() external {
        setUp();
        _jumpToNow();
    }

    function _initOrders(uint256 weekIdx) internal {
        OrderActs.Side side = OrderActs.Side.Ask;
        bool isCollectionBid = false;

        for (uint256 i = 0; i < collections.length; i++) {
            address collection = collections[i];

            uint256 seed = _seed(collection, side, isCollectionBid, weekIdx);

            uint256 limit = DNFT(collection).MAX_SUPPLY();
            uint8 density = (uint8(seed) % 6) + 2; // [2..7]

            MarketSim.selectTokens(collection, limit, density, seed);
        }

        // OrderActs.Order[] memory orders = new OrderActs.Order[](totalSelected);

        // for each collection => selectTokens()

        // push all selected to totalSelected and
    }

    function _seed(
        address collection,
        OrderActs.Side side,
        bool isCollectionBid,
        uint256 weekIdx
    ) internal returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(collection, side, isCollectionBid, weekIdx)
                )
            );
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
