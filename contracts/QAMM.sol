// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./QStateLib.sol";
import "./QCollapseEngine.sol";

contract QAMM {
    using QStateLib for QStateLib.Wave;

    QCollapseEngine public engine;

    struct Pool {
        QStateLib.Wave x;
        QStateLib.Wave y;
        uint24 feeBps;
    }

    mapping(bytes32 => Pool) public pools;

    event PoolCreated(bytes32 id);
    event SwapObserved(address indexed who, bytes32 poolId, uint256 dx, uint256 dy);
    event SwapDeferred(address indexed who, bytes32 poolId, uint256 dx, uint256 expectedDy);

    constructor(address _engine) { engine = QCollapseEngine(_engine); }

    function poolId(address a, address b) public pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a,b)) : keccak256(abi.encodePacked(b,a));
    }

    function createPool(bytes32 pid, QStateLib.Wave memory wx, QStateLib.Wave memory wy, uint24 feeBps) external {
        require(pools[pid].feeBps == 0, "exists");
        pools[pid] = Pool(wx, wy, feeBps);
        emit PoolCreated(pid);
    }

    function quoteExpected(bytes32 pid, uint256 dx) external view returns (uint256 dy) {
        Pool storage p = pools[pid];
        uint256 ex = p.x.expectedValue();
        uint256 ey = p.y.expectedValue();
        uint256 k = ex * ey;
        uint256 newX = ex + dx;
        uint256 newY = k / newX;
        dy = ey - newY;
        dy = (dy * (10000 - p.feeBps)) / 10000;
    }

    function swap(bytes32 pid, uint256 dx, bool observeBefore, uint256 delay, bytes32 salt) external returns (uint256 dy) {
        Pool storage p = pools[pid];
        if (observeBefore) {
            bytes32 sx = keccak256(abi.encodePacked("X", salt));
            bytes32 sy = keccak256(abi.encodePacked("Y", salt));
            bytes32 seedX = engine.deriveSeed(delay, sx);
            bytes32 seedY = engine.deriveSeed(delay, sy);
            uint8 ix = QStateLib.sampleIndex(p.x, seedX);
            uint8 iy = QStateLib.sampleIndex(p.y, seedY);
            uint256 X = QStateLib.valueAt(p.x, ix);
            uint256 Y = QStateLib.valueAt(p.y, iy);
            uint256 k = X * Y;
            uint256 newX = X + dx;
            uint256 newY = k / newX;
            dy = Y - newY;
            dy = (dy * (10000 - p.feeBps)) / 10000;
            p.x = QStateLib.buildDegenerate(newX);
            p.y = QStateLib.buildDegenerate(newY);
            emit SwapObserved(msg.sender, pid, dx, dy);
        } else {
            uint256 ex = p.x.expectedValue();
            uint256 ey = p.y.expectedValue();
            uint256 k = ex * ey;
            uint256 newEx = ex + dx;
            uint256 newEy = k / newEx;
            uint256 expectedDy = ey - newEy;
            expectedDy = (expectedDy * (10000 - p.feeBps)) / 10000;
            p.x = QStateLib.buildDegenerate(newEx);
            p.y = QStateLib.buildDegenerate(newEy);
            emit SwapDeferred(msg.sender, pid, dx, expectedDy);
            return expectedDy;
        }
    }
}

