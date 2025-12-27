// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

// core libs
import {OrderModel} from "orderbook/libs/OrderModel.sol";

// periphery libs
import {MarketSim} from "periphery/MarketSim.sol";

// interfaces
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";
import {ISettlementEngine} from "periphery/interfaces/ISettlementEngine.sol";
import {DNFT} from "periphery/interfaces/DNFT.sol";

// types
import {SignedOrder, SampleMode} from "dev/state/Types.sol";

abstract contract OrderSampling is Script {
    address[] internal collections;

    mapping(address => uint256[]) internal collectionSelected;

    address private weth;
    address private settlementContract;

    uint256 epoch;

    // any child contract must call this method
    function _initOrderSampling(
        uint256 _epoch,
        address[] memory _collections,
        address _settlementContract,
        address _weth
    ) internal {
        epoch = _epoch;
        collections = _collections;
        settlementContract = _settlementContract;
        weth = _weth;
    }

    function orderCount() internal view returns (uint256) {
        uint256 count;

        for (uint256 i = 0; i < collections.length; i++) {
            count += collectionSelected[collections[i]].length;
        }

        return count;
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

            uint256 seed = _orderSalt(collection, side, isCollectionBid, epoch);

            for (uint256 j = 0; j < tokens.length; j++) {
                uint256 tokenId = tokens[j];

                orders[k++] = _makeOrder(
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

        uint256 seed = _orderSalt(collection, side, isCollectionBid, epoch);

        // Safe: uint8(seed) % 6 ∈ [0..5], +2 ⇒ [2..7]
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 density = (uint8(seed) % 6) + 2;

        return MarketSim.selectTokens(collection, max, density, seed);
    }

    function _makeOrder(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 tokenId,
        uint256 price
    ) internal view returns (OrderModel.Order memory) {
        address owner = IERC721(collection).ownerOf(tokenId);

        uint256 j = 0;

        uint256 seed = uint256(
            keccak256(abi.encode(collection, owner, side, isCollectionBid, j))
        );

        while (
            ISettlementEngine(settlementContract).isUserOrderNonceInvalid(
                owner,
                _nonce(seed, j)
            )
        ) {
            j++;
        }

        return
            OrderModel.Order({
                side: side,
                isCollectionBid: isCollectionBid,
                collection: collection,
                tokenId: tokenId,
                currency: weth,
                price: price,
                actor: owner,
                start: uint64(block.timestamp),
                end: uint64(block.timestamp + 7 days),
                nonce: _nonce(seed, j)
            });
    }

    // === PRIVATE FUNCTIONS ===

    function _nonce(
        uint256 seed,
        uint256 attempt
    ) private pure returns (uint256) {
        return uint256(keccak256(abi.encode(seed, attempt)));
    }

    function _orderSalt(
        address collection,
        OrderModel.Side side,
        bool isCollectionBid,
        uint256 saltSeed
    ) internal pure returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(collection, side, isCollectionBid, saltSeed)
                )
            );
    }
}
