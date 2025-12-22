// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

// local
import {BaseDevScript} from "dev/BaseDevScript.s.sol";

// interfaces
import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";

/*
    for multiple NFT collections:

    just loop over all nft collections in one loop its easier

    function run() external {
        _loadConfig("deployments.toml", true);

        uint256 chainId = block.chainid;
        uint256[] memory participantPks = readKeys(chainId);

        address[] memory collections = _loadCollections();

        for (uint256 i = 0; i < collections.length; i++) {
            _bootstrapCollection(collections[i], participantPks);
        }
    }

    function _bootstrapCollection(
        address collection,
        uint256[] memory participantPks
    ) internal {
        IMintable721 nft = IMintable721(collection);
        uint256 supply = nft.MAX_SUPPLY();

        mintTokens(participantPks, nft, supply);
    }


*/

interface IMintable721 is IERC721 {
    function mint(address to) external;
    function MAX_SUPPLY() external view returns (uint256);
}

contract BootstrapNFTs is BaseDevScript, Config {
    function run() external {
        // --------------------------------
        // PHASE 0: LOAD CONFIG
        // --------------------------------
        _loadConfig("deployments.toml", true);

        logSection("LOAD CONFIG");

        uint256 chainId = block.chainid;
        console.log("ChainId: %s", chainId);

        address dNft = config.get("dmrktgremlin").toAddress();
        logAddress("DNFT    ", dNft);

        // --- PKs for broadcasting ---
        uint256[] memory participantPks = readKeys(chainId);
        uint256 participantCount = participantPks.length;

        // --------------------------------
        // PHASE 1: MINT NFTs
        // --------------------------------
        logSection("MINT NFTs");

        IMintable721 nftToken = IMintable721(address(dNft));
        uint256 supply = nftToken.MAX_SUPPLY();

        // script mints all tokens => limit = MAX_SUPPLY()
        mintTokens(participantPks, nftToken, supply);

        logSection("DNFT FINAL BALANCES");

        for (uint256 i = 0; i < participantCount; i++) {
            address user = addrOf(participantPks[i]);
            uint256 bal = nftToken.balanceOf(user);

            logTokenBalance("DNFT", user, bal);
        }
    }

    function mintTokens(
        uint256[] memory pks,
        IMintable721 nft,
        uint256 limit
    ) internal {
        // in this script we know i = tokenid for token minted (no previous mints)
        for (uint256 i = 0; i < limit; i++) {
            bytes32 h = keccak256(abi.encode(address(nft), i));
            uint256 j = uint256(h) % pks.length;

            uint256 pk = pks[j];
            address to = addrOf(pk);

            // Broadcast as the recipient — respect for history
            vm.startBroadcast(pk);

            nft.mint(to);

            vm.stopBroadcast();
        }
    }
}
