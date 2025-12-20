// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test} from "forge-std/Test.sol";

// local
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

abstract contract OrderHelper is Test {
    using OrderActs for OrderActs.Order;

    uint256 private constant DEFAULT_PRICE = 1 ether;
    uint256 private constant DEFAULT_TOKEN_ID = 1;

    bytes32 private domainSeparator;
    address private defaultCurrency; // WETH
    address private defaultCollection; // some erc721

    function _initOrderHelper(
        bytes32 _domainSeparator,
        address _defaultCollection,
        address _defaultCurrency
    ) internal {
        domainSeparator = _domainSeparator;
        defaultCollection = _defaultCollection;
        defaultCurrency = _defaultCurrency;
    }

    // === MAKE ORDERS ===

    // === ASK ===
    function makeAsk(
        address actor
    ) internal view returns (OrderActs.Order memory order) {
        return makeOrder(OrderActs.Side.Ask, false, actor);
    }

    function makeAsk(
        address collection,
        address currency,
        address actor
    ) internal view returns (OrderActs.Order memory) {
        return
            makeOrder(
                OrderActs.Side.Ask,
                collection,
                false,
                currency,
                DEFAULT_PRICE,
                actor,
                0
            );
    }

    // === BID / ASK ===

    function makeOrder(
        OrderActs.Side side,
        bool isCollectionBid,
        address actor
    ) internal view returns (OrderActs.Order memory) {
        return
            makeOrder(
                side,
                defaultCollection,
                isCollectionBid,
                defaultCurrency,
                DEFAULT_PRICE,
                actor,
                0
            );
    }

    function makeOrder(
        OrderActs.Side side,
        address collection,
        bool isCollectionBid,
        address currency,
        uint256 price,
        address actor,
        uint256 nonce
    ) internal view returns (OrderActs.Order memory) {
        return
            _makeOrder(
                side,
                collection,
                isCollectionBid,
                DEFAULT_TOKEN_ID,
                currency,
                price,
                actor,
                nonce
            );
    }

    function _makeOrder(
        OrderActs.Side side,
        address collection,
        bool isCollectionBid,
        uint256 tokenId,
        address currency,
        uint256 price,
        address actor,
        uint256 nonce
    ) internal view returns (OrderActs.Order memory) {
        return
            OrderActs.Order({
                side: side,
                actor: actor,
                isCollectionBid: isCollectionBid,
                collection: collection,
                currency: currency,
                tokenId: tokenId,
                price: price,
                start: 0,
                end: uint64(block.timestamp + 1 days),
                nonce: nonce
            });
    }

    // === DIGEST / SIGNING ===

    function makeDigest(
        OrderActs.Order memory o
    ) internal view returns (bytes32) {
        return
            keccak256(abi.encodePacked("\x19\x01", domainSeparator, o.hash()));
    }

    function makeDigestAndSign(
        OrderActs.Order memory order,
        uint256 signerPk
    ) internal view returns (bytes32 digest, SigOps.Signature memory sig) {
        digest = makeDigest(order);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        sig = SigOps.Signature(v, r, s);
    }

    function makeOrderDigestAndSign(
        address signer,
        uint256 signerPk
    )
        internal
        view
        returns (OrderActs.Order memory order, SigOps.Signature memory sig)
    {
        order = makeAsk(signer);
        bytes32 digest = makeDigest(order);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        sig = SigOps.Signature({v: v, r: r, s: s});
    }

    function dummySig() internal pure returns (SigOps.Signature memory) {
        return SigOps.Signature({v: 0, r: bytes32(0), s: bytes32(0)});
    }
}
