// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract QKernel {
    address public owner;
    mapping(bytes32 => address) public registry;

    event Registered(bytes32 indexed key, address impl);
    event OwnershipTransferred(address indexed from, address indexed to);

    modifier onlyOwner() {
        require(msg.sender == owner, "not-owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function set(bytes32 key, address impl) external onlyOwner {
        registry[key] = impl;
        emit Registered(key, impl);
    }

    function transferOwnership(address to) external onlyOwner {
        owner = to;
        emit OwnershipTransferred(msg.sender, to);
    }

    function get(bytes32 key) external view returns (address) {
        return registry[key];
    }
}

