// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC721} from "@openzeppelin/interfaces/IERC721.sol";

interface IMintable721 is IERC721 {
    function mint(address to, uint256 tokenId) external;
}
