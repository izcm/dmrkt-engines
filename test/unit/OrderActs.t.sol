// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

// local
import {OrderModel} from "orderbook/libs/OrderModel.sol";

contract OrderModelTest is Test {
    using OrderModel for OrderModel.Order;

    /*//////////////////////////////////////////////////////////////
                                IsAsk
    //////////////////////////////////////////////////////////////*/

    function test_IsAsk_ReturnsTrue_ForAsk() public {
        OrderModel.Order memory order = OrderModel.Order({
            side: OrderModel.Side.Ask,
            isCollectionBid: false,
            collection: address(0),
            tokenId: 0,
            currency: address(0),
            price: 0,
            actor: address(0),
            start: 0,
            end: 0,
            nonce: 0
        });

        assertTrue(order.isAsk());
    }

    function test_IsAsk_ReturnsFalse_ForBid() public {
        OrderModel.Order memory order = OrderModel.Order({
            side: OrderModel.Side.Bid,
            isCollectionBid: false,
            collection: address(0),
            tokenId: 0,
            currency: address(0),
            price: 0,
            actor: address(0),
            start: 0,
            end: 0,
            nonce: 0
        });

        assertFalse(order.isAsk());
    }

    /*//////////////////////////////////////////////////////////////
                                IsBid
    //////////////////////////////////////////////////////////////*/

    function test_IsBid_ReturnsTrue_ForBid() public {
        OrderModel.Order memory order = OrderModel.Order({
            side: OrderModel.Side.Bid,
            isCollectionBid: false,
            collection: address(0),
            tokenId: 0,
            currency: address(0),
            price: 0,
            actor: address(0),
            start: 0,
            end: 0,
            nonce: 0
        });

        assertTrue(order.isBid());
    }

    function test_IsBid_ReturnsFalse_ForAsk() public {
        OrderModel.Order memory order = OrderModel.Order({
            side: OrderModel.Side.Ask,
            isCollectionBid: false,
            collection: address(0),
            tokenId: 0,
            currency: address(0),
            price: 0,
            actor: address(0),
            start: 0,
            end: 0,
            nonce: 0
        });

        assertFalse(order.isBid());
    }
}
