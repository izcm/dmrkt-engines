// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";

/// @dev all periphery nfts implement the DNFT interface
/// @notice shorthand for DMrkt NFT

interface DNFT is IERC721 {
    function MAX_SUPPLY() external view returns (uint256);
}
