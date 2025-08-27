// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./QStateLib.sol";
import "./QCollapseEngine.sol";

contract QDAO {
    using QStateLib for QStateLib.Wave;

    QCollapseEngine public engine;

    struct ParamOutcome { bytes32 key; uint256 value; }
    struct Proposal {
        address proposer;
        uint64 startBlock;
        uint64 endBlock;
        QStateLib.Wave weights; // values = indices 0..n-1, probFrac from votes
        ParamOutcome[] outcomes;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals;
    uint256 public nextId;

    event Proposed(uint256 id, address who);
    event Voted(uint256 id, address who, uint8 outcomeIdx, uint256 weight);
    event Executed(uint256 id, uint8 idx, ParamOutcome outcome);

    constructor(address _engine) { engine = QCollapseEngine(_engine); }

    function propose(ParamOutcome[] calldata outs, uint256[] calldata weightsRaw) external returns (uint256 id) {
        require(outs.length == weightsRaw.length && outs.length > 0 && outs.length <= QStateLib.MAX_K, "bad");
        uint256[] memory idxVals = new uint256[](outs.length);
        for (uint256 i = 0; i < outs.length; ++i) idxVals[i] = i;
        QStateLib.Wave memory w = QStateLib.buildAliasWave(idxVals, weightsRaw);
        id = nextId++;
        Proposal storage p = proposals[id];
        p.proposer = msg.sender;
        p.startBlock = uint64(block.number);
        p.endBlock = uint64(block.number + 4500);
        p.weights = w;
        for (uint256 i = 0; i < outs.length; ++i) p.outcomes.push(outs[i]);
        emit Proposed(id, msg.sender);
    }

    function vote(uint256 id, uint8 outcomeIdx, uint256 weight) external {
        Proposal storage p = proposals[id];
        require(block.number <= p.endBlock, "closed");
        require(outcomeIdx < p.weights.k, "idx");
        // crude reweight: convert wave back to weights by using probFrac as weights proxy and add to chosen index
        uint256 k = p.weights.k;
        uint256[] memory vals = new uint256[](k);
        uint256[] memory wts = new uint256[](k);
        for (uint256 i = 0; i < k; ++i) {
            vals[i] = i;
            wts[i] = p.weights.probFrac[i];
        }
        wts[outcomeIdx] += weight;
        p.weights = QStateLib.buildAliasWave(vals, wts);
        emit Voted(id, msg.sender, outcomeIdx, weight);
    }

    function execute(uint256 id, uint256 delay, bytes32 salt) external {
        Proposal storage p = proposals[id];
        require(!p.executed, "done");
        require(block.number > p.endBlock, "open");
        bytes32 seed = engine.deriveSeed(delay, salt);
        uint8 idx = QStateLib.sampleIndex(p.weights, seed);
        ParamOutcome memory chosen = p.outcomes[idx];
        p.executed = true;
        emit Executed(id, idx, chosen);
    }
}

