// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./QStateLib.sol";
import "./QCollapseEngine.sol";

contract QInspector {
    using QStateLib for QStateLib.Wave;

    QCollapseEngine public engine;
    constructor(address _engine) { engine = QCollapseEngine(_engine); }

    function verifyCollapse(QStateLib.Wave memory w, uint256 delay, bytes32 salt, uint8 expectedIdx, uint256 expectedValue)
        external
        view
        returns (bool)
    {
        bytes32 seed = engine.deriveSeed(delay, salt);
        uint8 idx = QStateLib.sampleIndex(w, seed);
        uint256 v = QStateLib.valueAt(w, idx);
        return (idx == expectedIdx && v == expectedValue);
    }
}

