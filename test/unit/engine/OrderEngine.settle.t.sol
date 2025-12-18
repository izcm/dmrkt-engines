// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// local
import {OrderEngine} from "orderbook/OrderEngine.sol";
import {OrderActs} from "orderbook/libs/OrderActs.sol";

// helpers
import {OrderHelper} from "test-helpers/OrderHelper.sol";
import {AccountsHelper} from "test-helpers/AccountsHelper.sol";

/*
    // === REVERTS ===

    // fill.actor != msg.sender
    // invalid signature (wrong signer / wrong order fields)
    // reused nonce
    // order.actor == address(0)
    // currency != WETH
    // unsupported collection (not ERC721)
    // insufficient ERC20 allowance

    // === VALID ===

    // NFT transfers seller → fill.actor
    // WETH balances: buyer pays, seller receives (minus fee), protocol gets fee
    // nonce invalidated after settle
    // cannot settle same order twice

    // === SIGNATURE (INTEGRATION ONLY) ===
    
    // invalid signature causes settle to revert
    // valid signature allows settle to proceed
*/

contract OrderEngineSettleTest is OrderHelper, AccountsHelper {
    address immutable WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    OrderEngine orderEngine;
    address user = makeAddr("user");

    address[] actors;

    function setUp() public {
        orderEngine = new OrderEngine(WETH, address(this)); // fee receiver = this

        actors = allActors();
    }

    function test_Settle_InvalidSenderReverts() public {}
}
