// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {console} from "forge-std/console.sol";

// token interfaces
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";
import {IERC20, SafeERC20} from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

// local
import {OrderEngine} from "orderbook/OrderEngine.sol";
import {OrderActs} from "orderbook/libs/OrderActs.sol";
import {SignatureOps as SigOps} from "orderbook/libs/SignatureOps.sol";

// helpers
import {OrderHelper} from "test-helpers/OrderHelper.sol";
import {AccountsHelper} from "test-helpers/AccountsHelper.sol";
import {SettlementHelper} from "test-helpers/SettlementHelper.sol";

// mocks
import {MockWETH} from "mocks/MockWETH.sol";
import {MockERC721} from "mocks/MockERC721.sol";

// interfaces
import {IMintable721} from "periphery/interfaces/IMintable.sol";
import {IWETH} from "periphery/interfaces/IWETH.sol";
/*
    // === REVERTS ===

    // order.actor == address(0)
    // currency != WETH
    // unsupported collection (not ERC721)

    // === VALID ===

    // NFT transfers seller → fill.actor
    // WETH balances: buyer pays, seller receives (minus fee), protocol gets fee
    // nonce invalidated after settle

    // === SIGNATURE (INTEGRATION ONLY) ===

    // invalid signature causes settle to revert
    // valid signature allows settle to proceed
*/

// NOTE:
// Tests use SafeERC20 for consistency with production paths.
// ERC20 edge-case behavior is not explicitly tested here.
contract OrderEngineSettleTest is
    OrderHelper,
    AccountsHelper,
    SettlementHelper
{
    using SafeERC20 for IERC20; // mirrors actual engine
    using OrderActs for OrderActs.Order;

    uint256 constant DEFAULT_TOKENID = 1;

    OrderEngine orderEngine;
    bytes32 domainSeparator;

    // rn both are orderengine, vars added for future-proofing
    address erc721TransferAuthority;
    address erc20Spender;

    MockWETH wethToken;
    MockERC721 erc721Token;

    address weth;
    address erc721;

    function setUp() public {
        wethToken = new MockWETH();
        erc721Token = new MockERC721();

        weth = address(wethToken);
        erc721 = address(erc721Token);

        orderEngine = new OrderEngine(weth, address(this)); // fee receiver = this
        domainSeparator = orderEngine.DOMAIN_SEPARATOR();

        erc721TransferAuthority = address(orderEngine);
        erc20Spender = address(orderEngine);
    }

    /*//////////////////////////////////////////////////////////////
                                REVERTS
    //////////////////////////////////////////////////////////////*/
    function test_Settle_InvalidSenderReverts() public {
        Actors memory actors = someActors("invalid_sender");
        address txSender = vm.addr(actorCount() + 1); // private keys is [1, 2, 3... n]

        OrderActs.Order memory order = makeAsk(actors.order); // should fail before currency revert
        OrderActs.Fill memory fill = makeFill(actors.fill);
        SigOps.Signature memory sig = dummySig();

        vm.prank(txSender);
        vm.expectRevert(OrderEngine.UnauthorizedFillActor.selector);
        orderEngine.settle(fill, order, sig);
    }

    function test_Settle_ReusedNonceReverts() public {
        Actors memory actors = someActors("reuse_nonce");
        uint256 signerPk = pkOf(actors.order);

        OrderActs.Order memory order = makeAsk(actors.order, erc721, weth);

        (, SigOps.Signature memory sig) = makeDigestAndSign(
            order,
            domainSeparator,
            signerPk
        );

        OrderActs.Fill memory fill = makeFill(actors.fill);

        legitimizeSettlement(fill, order);

        // valid nonce
        vm.prank(actors.fill);
        orderEngine.settle(fill, order, sig);

        // replay nonce - should revert
        vm.prank(actors.fill);
        vm.expectRevert(OrderEngine.InvalidNonce.selector);
        orderEngine.settle(fill, order, sig);
    }

    // === INTERNAL HELPERS ===

    function legitimizeSettlement(
        OrderActs.Fill memory f,
        OrderActs.Order memory o
    ) internal {
        address collection = o.collection;
        uint256 price = o.price;
        address currency = o.currency;

        (
            address nftHolder,
            address spender,
            uint256 tokenId
        ) = expectRolesAndAsset(f, o);

        // future proofing in case future support for other currencies
        if (currency == weth) {
            dealWETHViaDeposit(spender, price);
        }

        // NFT
        vm.startPrank(nftHolder);
        mintMockNft(nftHolder, tokenId);
        approveNftTransfer(collection, erc721TransferAuthority, tokenId);
        vm.stopPrank();

        // ERC20
        vm.prank(spender);
        forceApproveAllowance(currency, erc20Spender, price);
    }

    function mintMockNft(address to, uint256 tokenId) internal {
        IMintable721(erc721).mint(to, tokenId);
    }

    function dealWETHViaDeposit(address to, uint256 amount) internal {
        vm.deal(to, amount);
        vm.prank(to);
        IWETH(weth).deposit{value: amount}();
    }

    function approveNftTransfer(
        address collection,
        address operator,
        uint256 tokenId
    ) internal {
        IERC721(collection).approve(operator, tokenId);
    }

    function forceApproveAllowance(
        address tokenContract,
        address spender,
        uint256 value
    ) internal {
        IERC20(tokenContract).forceApprove(spender, value);
    }

    function makeFill(
        address actor
    ) internal view returns (OrderActs.Fill memory fill) {
        return OrderActs.Fill({actor: actor, tokenId: DEFAULT_TOKENID});
    }

    function makeFill(
        address actor,
        uint256 tokenId
    ) internal pure returns (OrderActs.Fill memory fill) {
        return OrderActs.Fill({actor: actor, tokenId: tokenId});
    }
}
