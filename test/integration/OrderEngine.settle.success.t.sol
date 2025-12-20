// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// oz
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";

// local
import {OrderEngineSettleBase} from "./OrderEngine.settle.base.t.sol";

// libraries
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// === SETTLE SUCCESS PATHS ===
//
// 1) Ask order succeeds
//    - test_Settle_Ask_Succeeds
//
// 2) Bid order (specific tokenId) succeeds
//    - test_Settle_Bid_SpecificToken_Succeeds
//
// 3) Bid order (collection bid, fill.tokenId) succeeds
//    - test_Settle_Bid_CollectionBid_Succeeds
//  +
//  assertTrue(
//  orderEngine.isUserOrderNonceInvalid(order.actor, order.nonce)
//);
// for each test

struct Balances {
    uint256 spender;
    uint256 nftHolder;
    uint256 protocol;
}

contract OrderEngineSettleSuccessTest is OrderEngineSettleBase {
    function test_Settle_Ask_Succeeds() public {
        Actors memory actors = someActors("ask_success");
        uint256 signerPk = pkOf(actors.order);

        IERC721 nftToken = IERC721(erc721);

        OrderActs.Order memory order = makeAsk(
            actors.order,
            address(nftToken),
            wethAddr()
        );

        (, SigOps.Signature memory sig) = makeDigestAndSign(order, signerPk);

        OrderActs.Fill memory fill = makeFill(actors.fill);

        legitimizeSettlement(fill, order);

        (
            address nftHolder,
            address spender,
            uint256 tokenId
        ) = expectRolesAndAssets(fill, order);

        // check balance of parties before settlement
        IERC20 token = IERC20(order.currency);

        Balances memory beforeSuccess = _balanceOfParties(
            token,
            spender,
            nftHolder
        );

        vm.prank(actors.fill);
        orderEngine.settle(fill, order, sig);

        // check balance of parties after_ settlement
        Balances memory afterSuccess = _balanceOfParties(
            token,
            spender,
            nftHolder
        );

        _assertPayoutMatchesExpectations(
            beforeSuccess,
            afterSuccess,
            order.price
        );

        // check new ownership
        address finalNftHolder = nftToken.ownerOf(tokenId);
        assertEq(finalNftHolder, spender);

        assertTrue(
            orderEngine.isUserOrderNonceInvalid(order.actor, order.nonce)
        );
    }

    function test_Settle_Bid_SpecificToken_Succeeds() public {}

    function _assertPayoutMatchesExpectations(
        Balances memory before,
        Balances memory after_, // _ suffix since `after` is a reserved keyword
        uint256 orderPrice
    ) internal {
        uint256 fee = _protocolFee(orderPrice);
        uint256 payout = orderPrice - fee;

        uint256 spenderDiff = before.spender - after_.spender; // should decrease
        uint256 nftHolderDiff = after_.nftHolder - before.nftHolder; // should increase
        uint256 protocolDiff = after_.protocol - before.protocol; // should increase

        // assertEq(spenderDiff, payout);
        assertEq(nftHolderDiff, payout);
        assertEq(protocolDiff, fee);
    }

    function _protocolFee(uint256 price) internal view returns (uint256) {
        return (price * orderEngine.PROTOCOL_FEE_BPS()) / 10000;
    }

    function _balanceOfParties(
        IERC20 token,
        address spender,
        address nftHolder
    ) internal returns (Balances memory b) {
        b.spender = token.balanceOf(spender);
        b.nftHolder = token.balanceOf(nftHolder);
        b.protocol = token.balanceOf(protocolFeeRecipient);
    }
}
