// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "orderbook/libs/OrderModel.sol";

library FillBuilder {
    uint256 internal constant DEFAULT_TOKEN_ID = 0;

    function make(
        address actor
    ) internal pure returns (OrderModel.Fill memory) {
        return OrderModel.Fill({actor: actor, tokenId: DEFAULT_TOKEN_ID});
    }

    function make(
        address actor,
        uint256 tokenId
    ) internal pure returns (OrderModel.Fill memory) {
        return OrderModel.Fill({actor: actor, tokenId: tokenId});
    }
}
