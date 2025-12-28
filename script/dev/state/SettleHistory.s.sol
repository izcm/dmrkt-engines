// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {DevConfig} from "dev/DevConfig.s.sol";

import {OrderSampling} from "dev/logic/OrderSampling.s.sol";
import {OrderSnapshot} from "dev/logic/OrderSnapshot.s.sol";
import {SettlementSigner} from "dev/logic/SettlementSigner.s.sol";

// types
import {SignedOrder, SampleMode, Selection} from "dev/state/Types.sol";

// interfaces
import {ISettlementEngine} from "periphery/interfaces/ISettlementEngine.sol";
import {DNFT} from "periphery/interfaces/DNFT.sol";

// logging
import {console} from "forge-std/console.sol";

contract SettleHistory is
    OrderSampling,
    OrderSnapshot,
    SettlementSigner,
    BaseDevScript,
    DevConfig
{
    // ctx
    uint256 private weekIdx;

    bytes32 private domainSeparator;

    // === ENTRYPOINTS ===

    function runWeek(uint256 _weekIdx) external {
        logSection("SETTLE HISTORY");
        console.log("Week: %s", _weekIdx);
        logSeparator();

        weekIdx = _weekIdx;
        _bootstrap();
        _jumpToWeek();

        address[] memory collections = readCollections();
        console.log("Collections: %s", collections.length);

        OrderModel.Order[] memory orders;

        {
            // === SELECT TOKENIDS ===
            Selection[] memory selectionAsks = _collect(
                SampleMode.Ask,
                collections
            );

            Selection[] memory selectionBids = _collect(
                SampleMode.Bid,
                collections
            );

            Selection[] memory selectionCbs = _collect(
                SampleMode.CollectionBid,
                collections
            );

            // === ALLOCATE MEMORY ===
            uint256 count;

            for (uint256 i = 0; i < selectionAsks.length; i++) {
                count += selectionAsks[i].tokenIds.length;
            }
            for (uint256 i = 0; i < selectionBids.length; i++) {
                count += selectionBids[i].tokenIds.length;
            }
            for (uint256 i = 0; i < selectionCbs.length; i++) {
                count += selectionCbs[i].tokenIds.length;
            }

            console.log("Total orders to create: %s", count);
            orders = new OrderModel.Order[](count);

            uint256 idx;

            // === MAKE ORDERS ===

            for (uint256 i = 0; i < selectionAsks.length; i++) {
                Selection memory sel = selectionAsks[i];
                for (uint256 j = 0; j < sel.tokenIds.length; j++) {
                    orders[idx++] = makeOrder(
                        OrderModel.Side.Ask,
                        false,
                        sel.collection,
                        sel.tokenIds[j]
                    );
                }
            }

            for (uint256 i = 0; i < selectionBids.length; i++) {
                Selection memory sel = selectionBids[i];
                for (uint256 j = 0; j < sel.tokenIds.length; j++) {
                    orders[idx++] = makeOrder(
                        OrderModel.Side.Bid,
                        false,
                        sel.collection,
                        sel.tokenIds[j]
                    );
                }
            }

            for (uint256 i = 0; i < selectionCbs.length; i++) {
                Selection memory sel = selectionCbs[i];
                for (uint256 j = 0; j < sel.tokenIds.length; j++) {
                    orders[idx++] = makeOrder(
                        OrderModel.Side.Bid,
                        true,
                        sel.collection,
                        sel.tokenIds[j]
                    );
                }
            }
        }

        // === SIGN ORDERS ===

        logSection("SIGNING");

        SignedOrder[] memory signed = new SignedOrder[](orders.length);

        for (uint256 i = 0; i < orders.length; i++) {
            SigOps.Signature memory sig = signOrder(
                domainSeparator,
                orders[i],
                pkOf(orders[i].actor)
            );

            signed[i] = SignedOrder(orders[i], sig);
        }

        console.log("Orders signed: %s", signed.length);

        // === ORDER BY NONCE ===

        _sortByNonce(signed);

        console.log("Sorting by nonce completed");

        logSeparator();
        console.log(
            "Week %s ready with %s signed orders!",
            weekIdx,
            signed.length
        );
        logSeparator();

        // === FULFILL OR EXPORT ===

        if (_isFinalWeek()) {
            // export as JSON
            persistSignedOrders(signed, _jsonFilePath());
        } else {}
    }

    function finalize() external {
        _bootstrap();
        _jumpToNow();
    }

    // === SETUP / ENVIRONMENT ===

    function _bootstrap() internal {
        address sc = readSettlementContract();
        address weth = readWeth();

        domainSeparator = ISettlementEngine(sc).DOMAIN_SEPARATOR();

        _initOrderSampling(sc, weth);
        _loadParticipants();
    }

    function _sortByNonce(SignedOrder[] memory arr) internal pure {
        uint256 n = arr.length;

        for (uint256 i = 1; i < n; i++) {
            SignedOrder memory key = arr[i];
            uint256 keyNonce = key.order.nonce;

            uint256 j = i;
            while (j > 0 && arr[j - 1].order.nonce > keyNonce) {
                arr[j] = arr[j - 1];
                j--;
            }

            arr[j] = key;
        }
    }

    function _collect(
        SampleMode mode,
        address[] memory collections
    ) internal view returns (Selection[] memory selections) {
        selections = new Selection[](collections.length);

        for (uint256 i = 0; i < collections.length; i++) {
            address collection = collections[i];

            OrderModel.Side side = mode == SampleMode.Ask
                ? OrderModel.Side.Ask
                : OrderModel.Side.Bid;

            bool isCollectionBid = (mode == SampleMode.CollectionBid);

            uint256[] memory tokens = hydrateAndSelectTokens(
                side,
                isCollectionBid,
                collection,
                DNFT(collection).totalSupply(),
                weekIdx
            );

            selections[i] = Selection({
                collection: collection,
                tokenIds: tokens
            });
        }
    }

    // === TIME HELPERS ===

    function _jumpToWeek() internal {
        uint256 startTs = readStartTs();
        vm.warp(startTs + (weekIdx * 7 days));
    }

    function _jumpToNow() internal {
        vm.warp(readNowTs());
    }

    // === PRIVATE ===

    function _isFinalWeek() private view returns (bool) {
        return weekIdx == 4;
        // config.get("final_week_idx").toUint256();
    }

    function _jsonFilePath() private view returns (string memory) {
        return
            string.concat(
                "./data/",
                vm.toString(block.chainid),
                "/orders-raw.json"
            );
    }
}
