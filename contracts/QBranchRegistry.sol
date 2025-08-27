// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract QBranchRegistry {
    struct Branch { uint64 id; uint64 parent; address diff; string meta; }
    uint64 public nextId = 1;
    mapping(uint64 => Branch) public branches;

    event Branched(uint64 indexed id, uint64 parent, address diff);

    function createBranch(uint64 parent, address diff, string calldata meta) external returns (uint64 id) {
        id = nextId++;
        branches[id] = Branch(id, parent, diff, meta);
        emit Branched(id, parent, diff);
    }
}

