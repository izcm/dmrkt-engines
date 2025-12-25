// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// scripts
import {BaseDevScript} from "dev/BaseDevScript.s.sol";
import {BaseSettlement} from "dev/BaseSettlement.s.sol";

/*
abstract contract OrderSigning is BaseDevScript, BaseSettlement {
    function _initOrderSignint() internal {}

    function signOrders(
        OrderModel.Order[] memory orders
    ) internal view returns (SignedOrder[] memory signed) {
        uint256 len = orders.length;
        signed = new SignedOrder[](len);

        for (uint256 i = 0; i < len; i++) {
            OrderModel.Order memory order = orders[i];

            uint256 pk = pkOf(order.actor);
            require(pk != 0, "NO PK FOR ACTOR");

            signed[i] = SignedOrder({order: order, sig: signOrder(order, pk)});
        }
    }
}
*/
