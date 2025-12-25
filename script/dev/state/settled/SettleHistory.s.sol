// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";

// periphery libraries
import {MarketSim} from "periphery/MarketSim.sol";

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {BaseSettlement} from "dev/BaseSettlement.s.sol";

// DNFT => DmrktNFT (all implements these functions)
interface DNFT {
    function MAX_SUPPLY() external view returns (uint256); // periphery tokens all implement this
}

contract SettleHistory is BaseDevScript, BaseSettlement, Config {
    // ctx
    uint256 private historyStartTs;
    uint256 private weekIdx;

    address[] internal collections;

    mapping(address => uint256[]) internal collectionSelected;

    // === ENTRYPOINTS ===

    function runWeek(uint256 _weekIdx) external {
        weekIdx = _weekIdx;
        _bootstrap();
        _jumpToWeek();

        _collectAsks();
        _collectBids();
        _collectCollectionBids();
    }

    function finalize() external {
        _bootstrap();
        _jumpToNow();
    }

    // === SETUP / ENVIRONMENT ===

    function _bootstrap() internal {
        // --------------------------------
        // PHASE 0: LOAD CONFIG
        // --------------------------------
        _loadConfig("deployments.toml", true);

        logSection("LOAD CONFIG");

        uint256 chainId = block.chainid;

        console.log("ChainId: %s", chainId);

        // read .env
        historyStartTs = vm.envUint("historyStartTs");

        // read deployments.toml
        address marketplace = config.get("marketplace").toAddress();
        address weth = config.get("weth").toAddress();

        collections.push(config.get("dmrktgremlin").toAddress());

        _initBaseSettlement(marketplace, weth);

        // collections.push(config.get("dmrktgremlin").toAddress());
        // collections.push(config.get("kitz_erc721").toAddress());
        // collections.push(config.get("whatever_next").toAddress());
    }

    // === PIPELINE ===

    function _collectAsks() internal {
        logSection("COLLECT ORDERS - ASK");

        OrderModel.Side side = OrderModel.Side.Ask;
        bool isCollectionBid = false;

        _collect(side, isCollectionBid);
    }

    function _collectBids() internal {
        logSection("COLLECT ORDERS - BID");

        OrderModel.Side side = OrderModel.Side.Bid;
        bool isCollectionBid = false;

        _collect(side, isCollectionBid);
    }

    function _collectCollectionBids() internal {
        logSection("COLLECT ORDERS - COLLECTION BIDS");

        OrderModel.Side side = OrderModel.Side.Bid;
        bool isCollectionBid = true;

        _collect(side, isCollectionBid);
    }

    function _collect(OrderModel.Side side, bool isCollectionBid) internal {
        for (uint256 i = 0; i < collections.length; i++) {
            address collection = collections[i];

            uint256 seed = orderSalt(
                collection,
                side,
                isCollectionBid,
                weekIdx
            );

            uint256 limit = DNFT(collection).MAX_SUPPLY();

            // Safe: uint8(seed) % 6 ∈ [0..5], +2 ⇒ [2..7]
            // forge-lint: disable-next-line(unsafe-typecast)
            uint8 density = (uint8(seed) % 6) + 2;

            uint256[] memory tokens = MarketSim.selectTokens(
                collection,
                limit,
                density,
                seed
            );

            uint256 count = tokens.length;

            uint256[] storage acc = collectionSelected[collection];

            for (uint256 j = 0; j < count; j++) {
                acc.push(tokens[j]);
            }

            logTokenBalance("Selected tokens", collection, count);
            logSeparator();
        }
    }

    // === UTILITIES ===

    // === TIME HELPERS ===

    function _jumpToWeek() internal {
        // weekIndex = 0,1,2,3
        vm.warp(historyStartTs + (weekIdx * 7 days));
    }

    function _jumpToNow() internal {
        vm.warp(vm.envUint("NOW_TS"));
    }
}
