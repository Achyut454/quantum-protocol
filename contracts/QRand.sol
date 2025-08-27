// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract QRand {
    struct Commit { bytes32 h; uint64 blockNum; bool revealed; }
    mapping(address => Commit) public commits;
    bytes32 public pool;

    event Committed(address indexed who, bytes32 h);
    event Revealed(address indexed who, bytes32 secret, bytes32 newPool);

    constructor() {
        pool = keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp));
    }

    function commit(bytes32 h) external {
        commits[msg.sender] = Commit({h: h, blockNum: uint64(block.number), revealed: false});
        emit Committed(msg.sender, h);
    }

    function reveal(bytes32 secret) external {
        Commit storage c = commits[msg.sender];
        require(c.h != bytes32(0), "no-commit");
        require(!c.revealed, "already");
        require(keccak256(abi.encodePacked(secret, msg.sender, c.blockNum)) == c.h, "bad-secret");
        c.revealed = true;
        pool = keccak256(abi.encodePacked(pool, secret, msg.sender, block.prevrandao, blockhash(block.number - 1)));
        emit Revealed(msg.sender, secret, pool);
    }

    function seedDelayed(uint256 delay) external view returns (bytes32) {
        return keccak256(abi.encodePacked(pool, blockhash(block.number - 1), delay));
    }
}

