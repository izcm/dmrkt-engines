// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";

/*
1) Start anvil and copy ONE funded account + private key
2) Export it as FUNDER_KEY (env var)
3) Broadcast once from FUNDER_KEY and transfer ETH to my DEV users
4) Verify devAddr(i).balance > 0 on the node
5) Never use anvil accounts again — only broadcast as DEV_KEYS
*/
abstract contract BaseDevScript is Script {
    // DEV ONLY - anvil default funded accounts
    uint256[7] internal DEV_KEYS = [1, 2, 3, 4, 5, 6, 7];

    // addr derived from private key (here 1, 2, 3, 4)
    function devAddr(uint256 i) internal view returns (address) {
        return vm.addr(DEV_KEYS[i]);
    }

    // get private key for a dev address
    function devKey(address who) internal view returns (uint256) {
        for (uint256 i; i < DEV_KEYS.length; i++) {
            address a = devAddr(i);
            if (a == who) {
                return DEV_KEYS[i];
            }
        }
        revert("unknown dev addr");
    }

    function fundDevAccounts(uint256 amount) internal {
        for (uint256 i; i < DEV_KEYS.length; i++) {
            address a = devAddr(i);
            vm.deal(a, amount);
        }
    }

    function countUntilZero(
        uint256[] memory arr
    ) internal pure returns (uint256) {
        uint256 i = 0;
        while (i < arr.length && arr[i] != 0) {
            i++;
        }
        return i;
    }
}
