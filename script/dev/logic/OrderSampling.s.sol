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

abstract contract OrderSampling is Script {
    function orderSalt(
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

    function hydrateAndSelectTokens(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 scanLimit,
        uint256 seedSalt
    ) internal view returns (uint256[] memory) {
        uint256 seed = orderSalt(collection, side, isCollectionBid, seedSalt);
        // Safe: uint8(seed) % 6 ∈ [0..5], +2 ⇒ [2..7]
        // forge-lint: disable-next-line(unsafe-typecast)
        uint8 density = (uint8(seed) % 6) + 2;

        return MarketSim.selectTokens(collection, scanLimit, density, seed);
    }

    function makeOrder(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 tokenId,
        address currency,
        address settlementContract
    ) internal view returns (OrderModel.Order memory) {
        address owner = IERC721(collection).ownerOf(tokenId);

        uint256 j = 0;

        uint256 seed = uint256(orderSalt(collection, side, isCollectionBid, j));

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
                currency: currency,
                price: MarketSim.priceOf(collection, tokenId, seed),
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
}
