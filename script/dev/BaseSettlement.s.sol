// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

// core libs
import {OrderModel} from "orderbook/libs/OrderModel.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// periphery libs
import {OrderBuilder} from "periphery/builders/OrderBuilder.sol";

// interfaces
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";

// NOTE: interface is implemented to future proof
interface ISettlementEngine {
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function isUserOrderNonceInvalid(
        address user,
        uint256 nonce
    ) external view returns (bool);
}

abstract contract BaseSettlement is Script {
    using OrderModel for OrderModel.Order;

    address private settlementContract;
    address private weth;

    function _initBaseSettlement(
        address _settlementContract,
        address _weth
    ) internal {
        settlementContract = _settlementContract;
        weth = _weth;
    }

    function makeOrder(
        OrderModel.Side side,
        bool isCollectionBid,
        address collection,
        uint256 tokenId,
        uint256 price
    ) internal view returns (OrderModel.Order memory) {
        address owner = IERC721(collection).ownerOf(tokenId);

        uint256 j = 0;

        uint256 seed = uint256(
            keccak256(abi.encode(collection, owner, side, isCollectionBid, j))
        );

        while (
            ISettlementEngine(settlementContract).isUserOrderNonceInvalid(
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
        OrderModel.Order memory order,
        uint256 signerPk
    ) internal view returns (SigOps.Signature memory) {
        bytes32 digest = SigOps.digest712(
            ISettlementEngine(settlementContract).DOMAIN_SEPARATOR(),
            order.hash()
        );

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        return SigOps.Signature(v, r, s);
    }

    function orderSalt(
        address collection,
        OrderModel.Side side,
        bool isCollectionBid,
        uint256 epoch
    ) internal pure returns (uint256) {
        return
            uint256(
                keccak256(abi.encode(collection, side, isCollectionBid, epoch))
            );
    }

    // === PRIVATE FUNCTIONS ===

    function _nonce(
        uint256 seed,
        uint256 attempt
    ) private pure returns (uint256) {
        return uint256(keccak256(abi.encode(seed, attempt)));
    }
}
