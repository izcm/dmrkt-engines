// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {OrderActs} from "orderbook/libs/OrderActs.sol";

abstract contract SettlementHelper {
    using OrderActs for OrderActs.Order;

    /// @dev Expectation helper only.
    /// Does NOT check whether isBid purposefully so `settle` can revert `InvalidOrderSide`.
    function expectRolesAndAsset(
        OrderActs.Fill memory f,
        OrderActs.Order memory o
    )
        internal
        pure
        returns (address nftHolder, address spender, uint256 tokenId)
    {
        if (o.isAsk()) {
            return (o.actor, f.actor, o.tokenId);
        } else {
            return (
                f.actor,
                o.actor,
                o.isCollectionBid ? f.tokenId : o.tokenId
            );
        }
    }
}
