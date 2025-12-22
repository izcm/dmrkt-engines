// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "orderbook/libs/OrderActs.sol";

library OrderBuilder {
    function build(
        OrderActs.Side side,
        bool isCollectionBid,
        address collection,
        uint256 tokenId,
        address currency,
        uint256 price,
        address actor,
        uint64 start,
        uint64 end,
        uint256 nonce
    ) internal pure returns (OrderActs.Order memory) {
        return
            OrderActs.Order({
                side: side,
                isCollectionBid: isCollectionBid,
                collection: collection,
                tokenId: tokenId,
                currency: currency,
                price: price,
                actor: actor,
                start: start,
                end: end,
                nonce: nonce
            });
    }

    /// validation for dev-setup scripts
    function validate(OrderActs.Order memory o) internal {
        require(o.price > 0);
        require(o.end > o.start);
        require(o.actor != address(0));
        require(
            !(o.side == OrderActs.Side.Ask && o.isCollectionBid),
            "ask cannot be collection bid"
        );
    }
}
