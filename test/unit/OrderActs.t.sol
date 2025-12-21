// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// local
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {OrderHelper} from "test-helpers/OrderHelper.sol";

contract OrderActsTest is OrderHelper {
    using OrderActs for OrderActs.Order;

    address actor;

    function setup() public {
        actor = makeAddr("dummy");

        bytes32 dummyDomainSeparator = bytes32(
            keccak256(abi.encode("dummy_separator"))
        );
        address dummyCollection = makeAddr("dummy_collection");
        address dummyCurrency = makeAddr("dummy_currency");

        _initOrderHelper(dummyDomainSeparator, dummyCollection, dummyCurrency);
    }

    /*//////////////////////////////////////////////////////////////
                                IsAsk
    //////////////////////////////////////////////////////////////*/

    function test_IsAsk_ReturnsTrue_ForAsk() public {
        OrderActs.Side side = OrderActs.Side.Ask;

        OrderActs.Order memory order = makeOrder(side, false, actor);

        assertTrue(order.isAsk());
    }

    function test_IsAsk_ReturnsFalse_ForBid() public {
        OrderActs.Side side = OrderActs.Side.Bid;

        OrderActs.Order memory order = makeOrder(side, false, actor);
        assertFalse(order.isAsk());
    }

    /*//////////////////////////////////////////////////////////////
                                IsBid
    //////////////////////////////////////////////////////////////*/

    function test_IsBid_ReturnsTrue_ForBid() public {
        OrderActs.Side side = OrderActs.Side.Bid;

        OrderActs.Order memory order = makeOrder(side, false, actor);

        assertTrue(order.isBid());
    }

    function test_IsBid_ReturnsFalse_ForAsk() public {
        OrderActs.Side side = OrderActs.Side.Ask;

        OrderActs.Order memory order = makeOrder(side, false, actor);

        assertFalse(order.isBid());
    }
}
