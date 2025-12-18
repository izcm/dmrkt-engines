// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

// local
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

abstract contract OrderHelper is Test {
    using OrderActs for OrderActs.Order;

    address collection = makeAddr("collection");
    address currency = makeAddr("currency");

    function makeOrderDigestAndSign(
        address actor,
        uint256 actorPrivateKey,
        bytes32 domainSeparator
    ) internal view returns (OrderActs.Order memory, SigOps.Signature memory) {
        OrderActs.Order memory order = makeOrder(actor);
        bytes32 digest = makeDigest(order, domainSeparator);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(actorPrivateKey, digest);
        SigOps.Signature memory sig = SigOps.Signature({v: v, r: r, s: s});

        return (order, sig);
    }

    function makeOrder(
        address actor
    ) internal view returns (OrderActs.Order memory) {
        return makeOrder(actor, 0);
    }

    function makeOrder(
        address actor,
        uint256 nonce
    ) internal view returns (OrderActs.Order memory) {
        return makeOrder(actor, nonce, 1 ether);
    }

    function makeOrder(
        address actor,
        uint256 nonce,
        uint256 price
    ) internal view returns (OrderActs.Order memory) {
        return
            OrderActs.Order({
                side: OrderActs.Side.Ask,
                actor: actor,
                isCollectionBid: false,
                collection: collection,
                currency: currency,
                tokenId: 1,
                price: price,
                start: 0,
                end: uint64(block.timestamp + 1 days),
                nonce: nonce
            });
    }

    function makeDigest(
        OrderActs.Order memory o,
        bytes32 domainSeparator
    ) internal view returns (bytes32) {
        bytes32 msgHash = o.hash();

        return
            keccak256(abi.encodePacked("\x19\x01", domainSeparator, msgHash));
    }
}
