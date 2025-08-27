// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IQRandSeed {
    function seedDelayed(uint256 delay) external view returns (bytes32);
}

contract QCollapseEngine {
    IQRandSeed public rand;

    constructor(address _rand) {
        rand = IQRandSeed(_rand);
    }

    function deriveSeed(uint256 delay, bytes32 salt) external view returns (bytes32) {
        return keccak256(abi.encodePacked(rand.seedDelayed(delay), salt));
    }
}

