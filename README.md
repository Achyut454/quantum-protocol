# Quantum Economy Simulator (QES)

A Solidity-first simulation of quantum-like economics: probabilistic assets (QToken), AMM with superposed reserves (QAMM), probabilistic governance (QDAO), shared collapse engine seeded by on-chain randomness (QRand + QCollapseEngine), optional multiverse branching, and an inspector.

## Contracts

- contracts/QKernel.sol: simple registry for module addresses.
- contracts/QStateLib.sol: in-memory Wave model with Vose alias build, sampling, expected value, degenerate builder.
- contracts/QRand.sol: commit-reveal entropy pool and delayed seed derivation.
- contracts/QCollapseEngine.sol: derives a deterministic seed and exposes it to modules.
- contracts/QToken.sol: probabilistic balances with observe (collapse) and deferred transfers that preserve expected mass.
- contracts/QAMM.sol: constant-product AMM supporting observed and deferred swaps on Waves.
- contracts/QDAO.sol: proposals with probabilistic outcomes; execution collapses a parameter.
- contracts/QBranchRegistry.sol: minimal branching registry.
- contracts/QInspector.sol: read-only verification helper.

## Dev quickstart

1. Compile with your preferred tool (Foundry/Hardhat). Example (Foundry):

```
forge build
```

2. Deploy sequence (example):

- Deploy QRand.
- Deploy QCollapseEngine(rand).
- Deploy QToken(name,symbol,engine,Mode.Strict|Quantum).
- Use setWave(account, values, weights) to initialize distributions.

3. Interactions

- Observe: QToken.observe(user, delay, salt) collapses a user's wave to a concrete value.
- Transfer:
  - Strict/observeBefore: collapse both sides then move definite amount.
  - Quantum: proportional expected-mass adjustment across supports.
- AMM: QAMM.swap(pid, dx, observeBefore, delay, salt).
- Governance: QDAO.propose, QDAO.vote, QDAO.execute.

## Notes

- Probabilities use PREC = 1e18 scaling. K (support size) is capped at 16 for gas safety.
- Vose alias is used for O(1) sampling; seed consumed is deterministic from QRand.seedDelayed(delay) and salt.
- This implementation favors clarity. For production, prefer packed bytes storage and assembly for tighter gas.

## Security

- No external calls before state writes; keep K small; validate sums and bounds in production.
- Randomness without VRF is commit-reveal only; add a VRF-backed variant for higher assurance.
