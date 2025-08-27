// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./QStateLib.sol";
import "./QCollapseEngine.sol";

contract QToken {
    using QStateLib for QStateLib.Wave;

    string public name;
    string public symbol;
    uint8 public decimals = 18;

    enum Mode { Strict, Quantum }
    Mode public mode;

    QCollapseEngine public engine;
    uint256 public totalExpected;

    struct WaveStorage {
        uint8 k;
        uint256[] values;
        uint256[] probFrac;
        uint8[] aliasIndex;
    }

    mapping(address => WaveStorage) internal waves;

    event Observed(address indexed who, uint256 value, uint8 idx, bytes32 seed);
    event TransferObserved(address indexed from, address indexed to, uint256 amount);
    event TransferDeferred(address indexed from, address indexed to, uint256 amount);

    constructor(string memory n, string memory s, address _engine, Mode m) {
        name = n; symbol = s; engine = QCollapseEngine(_engine); mode = m;
    }

    function _loadWave(address who) internal view returns (QStateLib.Wave memory w) {
        WaveStorage storage s = waves[who];
        w.k = s.k;
        w.values = new uint256[](s.k);
        w.probFrac = new uint256[](s.k);
        w.aliasIndex = new uint8[](s.k);
        for (uint256 i = 0; i < s.k; ++i) {
            w.values[i] = s.values[i];
            w.probFrac[i] = s.probFrac[i];
            w.aliasIndex[i] = s.aliasIndex[i];
        }
    }

    function _storeWave(address who, QStateLib.Wave memory w) internal {
        WaveStorage storage s = waves[who];
        delete s.values; delete s.probFrac; delete s.aliasIndex;
        s.k = w.k;
        for (uint256 i = 0; i < w.k; ++i) {
            s.values.push(w.values[i]);
            s.probFrac.push(w.probFrac[i]);
            s.aliasIndex.push(w.aliasIndex[i]);
        }
    }

    function setWave(address who, uint256[] calldata values, uint256[] calldata weights) external {
        QStateLib.Wave memory w = QStateLib.buildAliasWave(values, weights);
        uint256 beforeExp = expectedBalance(who);
        _storeWave(who, w);
        uint256 afterExp = w.expectedValue();
        if (afterExp > beforeExp) totalExpected += (afterExp - beforeExp); else totalExpected -= (beforeExp - afterExp);
    }

    function expectedBalance(address who) public view returns (uint256) {
        WaveStorage storage s = waves[who];
        if (s.k == 0) return 0;
        QStateLib.Wave memory w = _loadWave(who);
        return w.expectedValue();
    }

    function observe(address who, uint256 delay, bytes32 salt) public returns (uint256) {
        QStateLib.Wave memory w = _loadWave(who);
        require(w.k > 0, "no-wave");
        bytes32 seed = engine.deriveSeed(delay, salt);
        uint8 idx = QStateLib.sampleIndex(w, seed);
        uint256 v = QStateLib.valueAt(w, idx);
        QStateLib.Wave memory deg = QStateLib.buildDegenerate(v);
        uint256 beforeExp = w.expectedValue();
        _storeWave(who, deg);
        if (v > beforeExp) totalExpected += (v - beforeExp); else totalExpected -= (beforeExp - v);
        emit Observed(who, v, idx, seed);
        return v;
    }

    function transfer(address to, uint256 amount, bool observeBefore, uint256 delay, bytes32 salt) external returns (bool) {
        if (mode == Mode.Strict || observeBefore) {
            uint256 fromBal = observe(msg.sender, delay, salt);
            require(fromBal >= amount, "insufficient");
            uint256 toBal = observe(to, delay, salt);
            QStateLib.Wave memory wf = QStateLib.buildDegenerate(fromBal - amount);
            QStateLib.Wave memory wt = QStateLib.buildDegenerate(toBal + amount);
            _storeWave(msg.sender, wf);
            _storeWave(to, wt);
            emit TransferObserved(msg.sender, to, amount);
            return true;
        } else {
            // Quantum: adjust expected mass proportionally
            QStateLib.Wave memory ws = _loadWave(msg.sender);
            QStateLib.Wave memory wd = _loadWave(to);
            require(ws.expectedValue() >= amount, "insufficient-exp");

            // sender: reduce expected mass proportionally
            uint256 totalScaled;
            for (uint256 i = 0; i < ws.k; ++i) totalScaled += ws.values[i] * ws.probFrac[i];
            uint256 amountScaled = amount * QStateLib.PREC;
            for (uint256 i = 0; i < ws.k; ++i) {
                uint256 contrib = ws.values[i] * ws.probFrac[i];
                uint256 delta = (amountScaled * contrib) / totalScaled;
                uint256 newContrib = contrib - delta;
                ws.values[i] = ws.probFrac[i] == 0 ? 0 : newContrib / ws.probFrac[i];
            }

            // receiver: add expected mass proportionally to probabilities or create degenerate
            if (wd.k == 0) {
                wd = QStateLib.buildDegenerate(amount);
            } else {
                uint256 totalProb;
                for (uint256 i = 0; i < wd.k; ++i) totalProb += wd.probFrac[i];
                uint256 amountScaledAdd = amount * QStateLib.PREC;
                for (uint256 i = 0; i < wd.k; ++i) {
                    uint256 addScaled = (amountScaledAdd * wd.probFrac[i]) / totalProb;
                    uint256 newContrib = wd.values[i] * wd.probFrac[i] + addScaled;
                    wd.values[i] = wd.probFrac[i] == 0 ? 0 : newContrib / wd.probFrac[i];
                }
            }

            _storeWave(msg.sender, ws);
            _storeWave(to, wd);
            emit TransferDeferred(msg.sender, to, amount);
            return true;
        }
    }
}

