// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

// core
import {OrderEngine} from "orderbook/OrderEngine.sol";

// core libs
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SettlementRoles} from "orderbook/libs/SettlementRoles.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// periphery libraries
import {MarketSim} from "periphery/MarketSim.sol";
import {OrderBuilder} from "periphery/builders/OrderBuilder.sol";

// interfaces
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";

abstract contract BaseSettlement is Script {
    using OrderActs for OrderActs.Order;

    address internal settlementContract; // futureproof name in case transfer auth decentralizes from order-settlementContract
    address internal weth;

    function _initBaseSettlement(
        address _settlementContract,
        address _weth
    ) internal {
        settlementContract = _settlementContract;
        weth = _weth;
    }

    function makeOrders(
        OrderActs.Side side,
        bool isCollectionBid,
        address collection,
        uint256 tokenId,
        uint256 price
    ) internal returns (OrderActs.Order memory) {
        address owner = IERC721(collection).ownerOf(tokenId);
        // uint256 price = MarketSim.priceOf(collection, tokenId, 0);

        uint256 j = 0;

        uint256 seed = uint256(
            keccak256(abi.encode(collection, owner, side, isCollectionBid, j))
        );

        while (
            OrderEngine(settlementContract).isUserOrderNonceInvalid(
                owner,
                _nonce(seed, j)
            )
        ) {
            j++;
        }

        return
            OrderBuilder.build(
                side,
                isCollectionBid,
                collection,
                tokenId,
                weth,
                price,
                owner,
                uint64(block.timestamp),
                uint64(block.timestamp + 7 days),
                _nonce(seed, j)
            );
    }

    function signOrder(
        OrderActs.Order memory order,
        uint256 signerPk
    ) internal view returns (SigOps.Signature memory) {
        bytes32 digest = SigOps.digest712(
            OrderEngine(settlementContract).DOMAIN_SEPARATOR(),
            order.hash()
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        return SigOps.Signature(v, r, s);
    }

    // === PRIVATE FUNCTIONS ===

    function _nonce(
        uint256 seed,
        uint256 attempt
    ) private pure returns (uint256) {
        return uint256(keccak256(abi.encode(seed, attempt)));
    }
}
