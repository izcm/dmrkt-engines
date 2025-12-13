// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// local
import {BaseDevScript} from "dev-script/BaseDevScript.s.sol";
import {OrderEngine} from "orderbook/OrderEngine.sol";
import {DMrktGremlin as DNFT} from "nfts/DMrktGremlin.sol";

// TODO: cryptopunks is not erc721 compatible, custom wrapper l8r?
// https://docs.openzeppelin.com/contracts/4.x/api/token/erc721
interface IERC721 {
    function setApprovalForAll(address operator, bool approved) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function transferFrom(address from, address to, uint256 tokenId) external;
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 amount) external returns (bool);
}

/*
    Note to self: 

    `new Orderengine()`: 
    bytes memory initCode = abi.encodePacked(
    type(OrderEngine).creationCode,
    abi.encode(args)
    );

    address engine;
    assembly {
    engine := create(0, add(initCode, 0x20), mload(initCode))
    }
 */

contract Setup is BaseDevScript, Config {
    uint256 immutable DEV_BOOTSTRAP_ETH = 10000 ether;

    OrderEngine public orderEngine;

    function run() external {
        // --------------------------------
        // PHASE 0: LOAD CONFIG
        // --------------------------------

        _loadConfig("deployments.toml", true);

        uint256 chainId = block.chainid;

        console.log("Deploying to chain: %s", chainId);

        address funder = config.get("funder").toAddress();
        address weth = config.get("weth").toAddress();

        console.log("----------");
        console.log("Funder address: %s", funder);
        console.log("Funders ETH balance: %s", funder.balance);
        console.log("----------");

        // --------------------------------
        // PHASE 1: SETUP CONTRACTS
        // --------------------------------

        // deploy dev nfts as funder
        uint256 funderPK = uint256(uint256(vm.envUint("PRIVATE_KEY")));

        // since the script uses the same private key its not necessary but just done to be more generic

        // deploy dmrkt nft and marketplace
        vm.startBroadcast(funderPK);
        OrderEngine oe = new OrderEngine();
        DNFT dNft = new DNFT();
        vm.stopBroadcast();

        console.log("----------");
        console.log("OrderEngine Deployed: %s", address(oe));
        console.log("DNFT Deployed: %s", address(dNft));
        console.log("----------");

        // --------------------------------
        // PHASE 2: FUND DEV ADDRS
        // --------------------------------

        // use devAddresses for local fork
        if (chainId == 1337) {
            uint256 distributableEth = (funder.balance * 9) / 10;
            uint256 devBootstrapEth = distributableEth / DEV_KEYS.length;

            vm.startBroadcast(funderPK);
            for (uint256 i = 1; i < DEV_KEYS.length; i++) {
                address a = devAddr(i);
                (bool ok, ) = payable(a).call{value: devBootstrapEth}("");
                if (!ok) {
                    console.log("Error sending eth to: %s", a);
                }
            }
            vm.stopBroadcast();

            // wrap ETH => WETH
            uint256 wethWrapAmount = devBootstrapEth / 2;

            for (uint256 i = 1; i < DEV_KEYS.length; i++) {
                vm.startBroadcast(i);
                IWETH(weth).deposit{value: wethWrapAmount}();
                vm.stopBroadcast();
            }
        }

        // for other chain use another system than BaseDevScript keys

        // deploy nft contract
        // select tokens
        /*(uint256[] memory ids) = selectTokens(azuki, 10, 2);

        // get number of tokens
        uint256 length = countUntilZero(ids);

        // --------------------------------
        // PHASE 1: PRANK OWNERS
        // --------------------------------

        address[] memory owners = new address[](length);

        // read owner
        for (uint256 i = 0; i < length; i++) {
            owners[i] = readOwnerOf(azuki, ids[i]);
            console.log("Owner of token %s: %s", ids[i], owners[i]);
        }

        // impersonate each owner
        for (uint256 i = 0; i < length; i++) {
            vm.prank(owners[i]);
            // transfer selected tokens to some a
            IERC721(azuki).transferFrom(
                owners[i], // ← ACTUAL OWNER
                a(1), // ← YOU
                ids[i]
            );
        }

        // read owner
        for (uint256 i = 0; i < length; i++) {
            owners[i] = readOwnerOf(azuki, ids[i]);
            console.log("Owner of token %s: %s", ids[i], owners[i]);
        }

        // --------------------------------
        // PHASE 2: BROADCAST - FUNDING
        // --------------------------------
        uint256 WRAP_AMOUNT = 100 ether;
        fundDevAccounts(DEV_BOOTSTRAP_ETH);

        // - wrap ETH =>  WETH
        vm.startBroadcast(2);
        // check the note in `BaseDevScript`
        // IWETH(weth).deposit{value: 1 ether}();
        // now user has weth... next is approval next step
        vm.stopBroadcast();
        // --------------------------------
        // PHASE 3: BROADCAST - APPROVALS
        // --------------------------------

        // - WETH allowance to marketplace
        // - Approve marketplace

        orderEngine = new OrderEngine();
        vm.stopBroadcast();

        // TODO: write the addr back to development.toml
        // console.log("\nEngine Deployed: %s", address(orderEngine));

        console.log(
            "\nDeployment complete! Addresses saved to deployments.toml"
        );
        */
    }

    function selectTokens(
        address tokenContract,
        uint256 scanLimit,
        uint256 targetCount,
        uint8 mod
    ) internal pure returns (uint256[] memory) {
        uint256 count = 0;
        uint256[] memory ids = new uint256[](targetCount);

        for (uint256 i = 0; i < scanLimit && count < targetCount; i++) {
            bytes32 h = keccak256(abi.encode(tokenContract, i));
            if (uint256(h) % mod == 0) {
                ids[count] = i;
                count++;
            }
        }

        assembly {
            mstore(ids, count)
        }

        return ids;
    }

    function readOwnerOf(
        address tokenContract,
        uint256 tokenId
    ) internal view returns (address) {
        return IERC721(tokenContract).ownerOf(tokenId);
    }
}
