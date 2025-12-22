// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

// core libs
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SettlementRoles} from "orderbook/libs/SettlementRoles.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

abstract contract BaseSettlement is Script {
    using OrderActs for OrderActs.Order;

    function signOrder(
        OrderActs.Order memory order,
        uint256 signerPk
    ) internal view returns (bytes32 digest, SigOps.Signature memory sig) {
        digest = SigOps.digest712("TMP", order.hash());

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        sig = SigOps.Signature(v, r, s);
    }
}
