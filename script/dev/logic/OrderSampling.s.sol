// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// periphery libs
import {MarketSim} from "periphery/MarketSim.sol";

// core libs
import {OrderModel} from "orderbook/libs/OrderModel.sol";

// scripts
import {BaseSettlement} from "dev/BaseSettlement.s.sol";

// interfaces
import {DNFT} from "periphery/interfaces/DNFT.sol";

/*
    TODO: MAYBE make more DRY with: 

    enum SampleMode {
        Ask,
        Bid,
        CollectionBid
    }

    function collect(SampleMode mode) internal {
        _resetSelection();

        if (mode == SampleMode.Ask) {
            _selectAndStore(OrderModel.Side.Ask, false);
        } else if (mode == SampleMode.Bid) {
            _selectAndStore(OrderModel.Side.Bid, false);
        } else {
            _selectAndStore(OrderModel.Side.Bid, true);
        }
    }

    Do this after implementing `SettleHistory`
 */
abstract contract OrderSampling is BaseSettlement {
    uint256 private epoch; // used to set order.timestamps
    uint256 private seedSalt; // lets child contracts influence seeds for selecting tokensIds

    address[] internal collections;

    mapping(address => uint256[]) internal collectionSelected;

    // any child contract must call this method
    function _initOrderSampling(
        uint256 _epoch,
        uint256 _seedSalt,
        address[] memory _collections
    ) internal {
        epoch = _epoch;
        seedSalt = _seedSalt;
        collections = _collections;
    }

    function orderCount() internal view returns (uint256) {
        uint256 count;

        for (uint256 i = 0; i < collections.length; i++) {
            count += collectionSelected[collections[i]].length;
        }

        return count;
    }

    function collectAsks() internal {
        _resetSelection();

        OrderModel.Side side = OrderModel.Side.Ask;
        bool isCollectionBid = false;

        _selectAndStore(side, isCollectionBid);
    }

    function collectBids() internal {
        _resetSelection();

        OrderModel.Side side = OrderModel.Side.Bid;
        bool isCollectionBid = false;

        _selectAndStore(side, isCollectionBid);
    }

    function collectCollectionBids() internal {
        _resetSelection();

        OrderModel.Side side = OrderModel.Side.Bid;
        bool isCollectionBid = true;

        _selectAndStore(side, isCollectionBid);
    }

    function _resetSelection() internal {
        for (uint256 i = 0; i < collections.length; i++) {
            delete collectionSelected[collections[i]];
        }
    }

    function _selectAndStore(
        OrderModel.Side side,
        bool isCollectionBid
    ) internal {
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
        }
    }

    function _hydrateAndSelectTokens(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection
    ) internal view returns (uint256[] memory) {
        uint256 max = DNFT(collection).totalSupply();

        uint256 seed = orderSalt(collection, side, isCollectionBid, seedSalt);

        // Safe: uint8(seed) % 6 ∈ [0..5], +2 ⇒ [2..7]
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 density = (uint8(seed) % 6) + 2;

        return MarketSim.selectTokens(collection, max, density, seed);
    }

    function buildOrders(
        OrderModel.Side side,
        bool isCollectionBid
    ) internal view returns (OrderModel.Order[] memory) {
        uint256 count = orderCount();

        OrderModel.Order[] memory orders = new OrderModel.Order[](count);

        uint256 k;

        // second pass: fill
        for (uint256 i = 0; i < collections.length; i++) {
            address collection = collections[i];
            uint256[] storage tokens = collectionSelected[collection];

            uint256 seed = orderSalt(
                collection,
                side,
                isCollectionBid,
                seedSalt
            );

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
}
