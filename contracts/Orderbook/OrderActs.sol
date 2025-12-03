library OrderActs {
    enum Side {
        Ask,
        Bid
    }

    struct Order {
        address actor;
        Side side;
        uint64 start;
        uint64 end;
        uint256 nonce;
        bytes constraints;
    }

    struct Fill {}

    bytes32 constant ORDER_HASH = keccak256("todo");

    function hash(Order memory order) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                ORDER_HASH, order.actor, order.side, order.start, order.end, order.nonce, keccak256(order.constraints)
            )
        );
    }
}

