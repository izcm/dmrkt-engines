// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

// local
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";
import {OrderHelper} from "test-helpers/OrderHelper.sol";

// mocks
import {MockVerifyingContract} from "../mocks/MockVerifyingContract.sol";

contract SignatureOpsTest is OrderHelper {
    MockVerifyingContract verifier;

    uint256 userPrivateKey;
    uint256 signerPrivateKey;

    address user;
    address signer;

    function setUp() public {
        verifier = new MockVerifyingContract(keccak256("TEST_DOMAIN"));

        userPrivateKey = 0xabc123;
        signerPrivateKey = 0x123abc;

        user = vm.addr(userPrivateKey);
        signer = vm.addr(signerPrivateKey);
    }

    function test_Verify_ValidSignature_Succeeds() public {
        (
            OrderActs.Order memory order,
            SigOps.Signature memory sig
        ) = makeOrderDigestAndSign(
                signer,
                signerPrivateKey,
                verifier.DOMAIN_SEPARATOR()
            );

        vm.prank(user);
        verifier.verify(order, sig);
    }

    function test_Verify_CorruptedS_Reverts() public {
        (
            OrderActs.Order memory order,
            SigOps.Signature memory sig
        ) = makeOrderDigestAndSign(
                signer,
                signerPrivateKey,
                verifier.DOMAIN_SEPARATOR()
            );

        // simulate corrupt s <= n/2 https://eips.ethereum.org/EIPS/eip-2
        sig.s = bytes32(
            uint256(
                0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
            ) + 1
        );

        vm.prank(user);
        vm.expectRevert(SigOps.InvalidSParameter.selector);
        verifier.verify(order, sig);
    }

    function test_Verify_CorruptedV_Reverts() public {}

    function test_Verify_WrongSigner_Reverts() public {
        (
            OrderActs.Order memory order,
            SigOps.Signature memory sig
        ) = makeOrderDigestAndSign(
                signer,
                signerPrivateKey,
                verifier.DOMAIN_SEPARATOR()
            );

        order.actor = makeAddr("imposter");

        vm.expectRevert(SigOps.InvalidSignature.selector);
        verifier.verify(order, sig);
    }
}
