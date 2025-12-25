// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// foundry
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {BaseSettlement} from "dev/BaseSettlement.s.sol";

import {OrderSampling} from "dev/logic/OrderSampling.s.sol";

struct SignedOrder {
    OrderModel.Order order;
    SigOps.Signature sig;
}

contract OpenListings is BaseDevScript, BaseSettlement, OrderSampling, Config {
    // ctx
    uint256 chainId;

    function run() external {
        // === LOAD CONFIG ===

        _loadConfig("deployments.toml", true);

        logSection("CONFIG");

        chainId = block.chainid;
        console.log("ChainId: %s", chainId);

        // currencies
        address weth = config.get("weth").toAddress();

        // deployed contracts
        collections.push(config.get("dmrktgremlin").toAddress()); // TODO: will be more collections later

        address settlementContract = config
            .get("settlement_contract")
            .toAddress();

        logAddress("SETTLER ", settlementContract);

        // === INITIALIZE AND SET PATHS ===
        _initBaseSettlement(settlementContract, weth);
        _initOrderSampling(0, 0, collections);

        // loads pk => addr => to easily fetch addresses
        _loadParticipants();

        string memory basePath = string.concat(
            "./data/",
            vm.toString(chainId),
            "/orders-raw"
        );

        // === COLLECT ORDERS AND EXPORT ===

        logSection("COLLECTING ORDERS");

        // === collect => build => JSON ===

        // ASKS

        {
            collectAsks(); // collects and stores tokenids with `ask` seed

            SignedOrder[] memory signed = _buildAndSignAsks();

            _persistSignedOrders(signed, string.concat(basePath, ".ask.json"));
        }

        // BIDS

        {
            collectBids(); // collects and stores tokenids with `ask` seed

            SignedOrder[] memory signed = _buildAndSignBids();

            _persistSignedOrders(signed, string.concat(basePath, ".bid.json"));
        }

        // COLLECTION BIDS

        {
            collectCollectionBids(); // collects and stores tokenids with `ask` seed

            SignedOrder[] memory signed = _buildAndSignCollectionBids();

            _persistSignedOrders(signed, string.concat(basePath, ".cb.json"));
        }
    }

    function _buildAndSignAsks() internal returns (SignedOrder[] memory) {
        return _buildAndSignOrders(OrderModel.Side.Ask, false);
    }

    function _buildAndSignBids() internal returns (SignedOrder[] memory) {
        return _buildAndSignOrders(OrderModel.Side.Bid, false);
    }

    function _buildAndSignCollectionBids()
        internal
        returns (SignedOrder[] memory)
    {
        return _buildAndSignOrders(OrderModel.Side.Bid, true);
    }

    function _buildAndSignOrders(
        OrderModel.Side side,
        bool isCollectionBid
    ) internal returns (SignedOrder[] memory) {
        OrderModel.Order[] memory orders = buildOrders(side, isCollectionBid); // OrderSampling builds the orders stored in collectionSelected mapping

        uint256 count = orders.length;

        SignedOrder[] memory signed = new SignedOrder[](count);

        for (uint256 i = 0; i < count; i++) {
            OrderModel.Order memory order = orders[i];

            uint256 pk = pkOf(order.actor);
            require(pk != 0, "NO PK FOR ACTOR");

            (SigOps.Signature memory sig) = signOrder(order, pk);

            signed[i] = SignedOrder({order: order, sig: sig});
        }

        return signed;
    }

    function _persistSignedOrders(
        SignedOrder[] memory signedOrders,
        string memory path
    ) internal {
        uint256 signedOrderCount = signedOrders.length;
        string memory root = "root";

        // metadata
        vm.serializeUint(root, "chainId", chainId);

        // signedOrders array
        string[] memory entries = new string[](signedOrderCount);

        for (uint256 i = 0; i < signedOrderCount; i++) {
            SignedOrder memory signed = signedOrders[i];

            string memory oKey = string.concat(
                "order_",
                vm.toString(uint256(1))
            );

            entries[i] = _serializeOrder(signed.order, oKey);

            // ---- signature ----
            SigOps.Signature memory sig = signed.sig;

            string memory sKey = string.concat(oKey, "sig");

            vm.serializeUint(sKey, "v", sig.v);
            vm.serializeBytes32(sKey, "r", sig.r);
            vm.serializeBytes32(sKey, "s", sig.s);

            // Foundry serialize API requires a terminal value to emit object
            string memory sigOut = vm.serializeString(sKey, "_", "0");

            string memory output = vm.serializeString(
                oKey,
                "signature",
                sigOut
            );
            entries[i] = output;
        }

        string memory finalJson = vm.serializeString(
            root,
            "signedOrders",
            entries
        );

        vm.writeJson(finalJson, path);

        logSeparator();
        console.log("ORDERS SAVED TO: %s", path);
        logSeparator();
    }

    function _serializeOrder(
        OrderModel.Order memory o,
        string memory objKey
    ) internal returns (string memory) {
        string memory key = objKey;

        // ---- order ----
        vm.serializeUint(key, "side", uint256(o.side));
        vm.serializeAddress(key, "actor", o.actor);
        vm.serializeBool(key, "isCollectionBid", o.isCollectionBid);
        vm.serializeAddress(key, "collection", o.collection);
        vm.serializeString(key, "tokenId", vm.toString(o.tokenId));
        vm.serializeString(key, "price", vm.toString(o.price));
        vm.serializeAddress(key, "currency", o.currency);
        vm.serializeUint(key, "start", o.start);
        vm.serializeUint(key, "end", o.end);
        vm.serializeString(key, "nonce", vm.toString(o.nonce));

        return key;
    }
}
