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
    using OrderModel for OrderModel.Order;

    // ctx
    uint256 private weekIdx;

    // === ENTRYPOINTS ===

    function runWeek(uint256 _weekIdx) external {
        // === LOAD CONFIG & SETUP ===

        address settlementContract = readSettlementContract();
        address weth = readWeth();

        bytes32 domainSeparator = ISettlementEngine(settlementContract)
            .DOMAIN_SEPARATOR();

        _loadParticipants();

        weekIdx = _weekIdx;
        _jumpToWeek();

        logSection("SETTLE HISTORY");
        console.log("Week: %s", weekIdx);
        logSeparator();

        address[] memory collections = readCollections();
        console.log("Collections: %s", collections.length);

        // === BUILD ORDERS ===

        OrderModel.Order[] memory orders = _buildOrders(
            settlementContract,
            weth,
            collections
        );

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
        } else {
            // match each mode with a fill
            matchOrdersWithFill(orders);
        }
    }

    function finalize() external {
        _jumpToNow();
    }

    function matchOrdersWithFill(
        OrderModel.Order[] memory orders
    ) internal view {
        OrderModel.Fill[] memory fills = new OrderModel.Fill[](orders.length);

        for (uint256 i = 0; i < orders.length; i++) {
            fills[i] = _matchOrderWithFill(orders[i]);
        }
    }

    function _matchOrderWithFill(
        OrderModel.Order memory order
    ) internal view returns (OrderModel.Fill memory fill) {
        if (order.isAsk()) {
            _fillAsk(order);
        } else if (order.isBid()) {
            _fillBid(order);
        } else {
            revert("Invalid Order Side");
        }
    }

    function _fillAsk(OrderModel.Order memory order) internal view {
        // read price
        uint256 price = order.price;
        // fetch some participant
        address ps = participant(0); // TODO: fix this
        // check marketplace weth allowance

        // read participant PK
        // broadcast as participant
        // call settle
    }

    function _fillBid(OrderModel.Order memory order) internal view {
        if (order.isCollectionBid) {
            _fillCollectionBid(order);
        } else {
            _fillRegularBid(order);
        }
    }

    function _fillRegularBid(OrderModel.Order memory order) internal view {}

    function _fillCollectionBid(OrderModel.Order memory order) internal view {}

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

    function _buildOrders(
        address settlementContract,
        address weth,
        address[] memory collections
    ) internal view returns (OrderModel.Order[] memory orders) {
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

        uint256 count;
        for (uint256 i; i < selectionAsks.length; i++)
            count += selectionAsks[i].tokenIds.length;
        for (uint256 i; i < selectionBids.length; i++)
            count += selectionBids[i].tokenIds.length;
        for (uint256 i; i < selectionCbs.length; i++)
            count += selectionCbs[i].tokenIds.length;

        orders = new OrderModel.Order[](count);
        uint256 idx;

        idx = _appendOrders(
            orders,
            idx,
            OrderModel.Side.Ask,
            false,
            selectionAsks,
            weth,
            settlementContract
        );

        idx = _appendOrders(
            orders,
            idx,
            OrderModel.Side.Bid,
            false,
            selectionBids,
            weth,
            settlementContract
        );

        _appendOrders(
            orders,
            idx,
            OrderModel.Side.Bid,
            true,
            selectionCbs,
            weth,
            settlementContract
        );
    }

    function _appendOrders(
        OrderModel.Order[] memory orders,
        uint256 idx,
        OrderModel.Side side,
        bool isCollectionBid,
        Selection[] memory selections,
        address weth,
        address settlementContract
    ) internal view returns (uint256) {
        for (uint256 i; i < selections.length; i++) {
            Selection memory sel = selections[i];
            for (uint256 j; j < sel.tokenIds.length; j++) {
                orders[idx++] = makeOrder(
                    side,
                    isCollectionBid,
                    sel.collection,
                    sel.tokenIds[j],
                    weth,
                    settlementContract
                );
            }
        }
        return idx;
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
