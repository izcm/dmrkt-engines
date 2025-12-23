// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// foundry
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// core libraries
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// periphery libraries
import {MarketSim} from "periphery/MarketSim.sol";

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {BaseSettlement} from "dev/BaseSettlement.s.sol";

// interfaces
import {DNFT} from "periphery/interfaces/DNFT.sol";

struct SignedOrder {
    OrderModel.Order order;
    SigOps.Signature sig;
}

contract BuildOrders is BaseDevScript, BaseSettlement, Config {
    // ctx
    uint256 chainId;
    uint256 internal epoch = 3; // 3 because MakeHistory has [0, 1, 2]  (plz dont hardcode this forever)

    address[] internal collections;

    mapping(address => uint256[]) internal collectionSelected;

    function run() external {
        // --------------------------------
        // PHASE 0: LOAD CONFIG
        // --------------------------------
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

        _initBaseSettlement(settlementContract, weth);
        _loadParticipants();

        // --------------------------------
        // PHASE 1: MAKE ORDERS
        // --------------------------------
        logSection("MAKE ORDERS");

        OrderModel.Order[] memory orders = _collectAsks();
        uint256 orderCount = orders.length;

        SignedOrder[] memory signed = new SignedOrder[](orderCount);

        // --- sign orders ---

        for (uint256 i = 0; i < orderCount; i++) {
            OrderModel.Order memory order = orders[i];

            uint256 pk = pkOf(order.actor);
            require(pk != 0, "NO PK FOR ACTOR");

            (SigOps.Signature memory sig) = signOrder(order, pk);

            signed[i] = SignedOrder({order: order, sig: sig});
        }

        // --------------------------------
        // PHASE 2: WRITE AS JSON
        // --------------------------------
        logSection("WRITING ORDERS AS JSON");

        string memory path = string.concat(
            "./data/",
            vm.toString(chainId),
            "/orders-raw.json"
        );

        _persistSignedOrders(signed, path, settlementContract);

        logSeparator();
        console.log("ORDERS SAVED TO: %s", path);
        logSeparator();
    }

    function _collectAsks() internal returns (OrderModel.Order[] memory) {
        logSection("COLLECT ORDERS - ASK");

        OrderModel.Side side = OrderModel.Side.Ask;
        bool isCollectionBid = false;

        return _selectAndStore(side, isCollectionBid);
    }

    function _selectAndStore(
        OrderModel.Side side,
        bool isCollectionBid
    ) internal returns (OrderModel.Order[] memory) {
        for (uint256 i = 0; i < collections.length; i++) {
            address collection = collections[i];

            uint256[] memory tokens = _hydrateAndSelectTokens(
                side,
                isCollectionBid,
                collection
            );

            uint256[] storage acc = collectionSelected[collection];
            for (uint256 j = 0; j < tokens.length; j++) {
                acc.push(tokens[j]);
            }

            logTokenBalance("Selected tokens", collection, tokens.length);
            logSeparator();
        }

        return _buildOrders(side, isCollectionBid);
    }

    function _hydrateAndSelectTokens(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection
    ) internal view returns (uint256[] memory) {
        uint256 max = DNFT(collection).MAX_SUPPLY();

        uint256 seed = orderSalt(collection, side, isCollectionBid, epoch);

        // Safe: uint8(seed) % 6 ∈ [0..5], +2 ⇒ [2..7]
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 density = (uint8(seed) % 6) + 2;

        return MarketSim.selectTokens(collection, max, density, seed);
    }

    function _buildOrders(
        OrderModel.Side side,
        bool isCollectionBid
    ) internal view returns (OrderModel.Order[] memory) {
        uint256 total;

        // first pass: count
        for (uint256 i = 0; i < collections.length; i++) {
            total += collectionSelected[collections[i]].length;
        }

        OrderModel.Order[] memory orders = new OrderModel.Order[](total);

        uint256 k;

        // second pass: fill
        for (uint256 i = 0; i < collections.length; i++) {
            address collection = collections[i];
            uint256[] storage tokens = collectionSelected[collection];

            uint256 seed = orderSalt(collection, side, isCollectionBid, epoch);

            for (uint256 j = 0; j < tokens.length; j++) {
                uint256 tokenId = tokens[j];

                orders[k++] = makeOrder(
                    side,
                    isCollectionBid,
                    collection,
                    tokenId,
                    MarketSim.priceOf(collection, tokenId, seed)
                );
            }
        }

        return orders;
    }

    function _persistSignedOrders(
        SignedOrder[] memory signedOrders,
        string memory path,
        address settlementContract
    ) internal {
        uint256 signedOrderCount = signedOrders.length;
        string memory root = "root";

        // metadata
        vm.serializeUint(root, "chainId", chainId);
        vm.serializeAddress(root, "settlementContract", settlementContract);

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

            // tried to avoid including this value, but harder than imagined...
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
