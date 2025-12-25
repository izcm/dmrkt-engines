// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @dev dev-only interface for periphery NFTs used in scripts/sims
/// @notice shorthand for DMrkt NFT

interface DNFT {
    function MAX_SUPPLY() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
