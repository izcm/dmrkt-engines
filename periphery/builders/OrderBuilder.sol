// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "orderbook/libs/OrderModel.sol";

library OrderBuilder {
    function build(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 tokenId,
        address currency,
        uint256 price,
        address actor,
        uint64 start,
        uint64 end,
        uint256 nonce
    ) internal pure returns (OrderModel.Order memory) {
        return
            OrderModel.Order({
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
    function validate(OrderModel.Order memory o) internal pure {
        require(o.price > 0);
        require(o.end > o.start);
        require(o.actor != address(0));
        require(
            !(o.side == OrderModel.Side.Ask && o.isCollectionBid),
            "ask cannot be collection bid"
        );
    }
}
