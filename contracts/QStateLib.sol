// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library QStateLib {
    uint256 internal constant PREC = 1e18; // probabilities scaled by 1e18
    uint8 internal constant MAX_K = 16;

    struct Wave {
        uint8 k;                 // support size
        uint256[] values;        // length k
        uint256[] probFrac;      // length k, each in [0..PREC], sum to PREC
        uint8[] aliasIndex;      // length k, alias pointers
        bytes32 merkleRoot;      // optional commitment for audits
    }

    function buildAliasWave(uint256[] memory values, uint256[] memory weights)
        internal
        pure
        returns (Wave memory w)
    {
        require(values.length == weights.length, "len-mismatch");
        uint256 k = values.length;
        require(k > 0 && k <= MAX_K, "bad-k");

        uint256 sumW;
        for (uint256 i = 0; i < k; ++i) sumW += weights[i];
        require(sumW > 0, "zero-sum");

        w.k = uint8(k);
        w.values = new uint256[](k);
        w.probFrac = new uint256[](k);
        w.aliasIndex = new uint8[](k);

        // scaled = weights[i] * k * PREC / sumW
        uint256[] memory scaled = new uint256[](k);
        for (uint256 i = 0; i < k; ++i) {
            w.values[i] = values[i];
            scaled[i] = (weights[i] * k * PREC) / sumW;
        }

        uint8[] memory small = new uint8[](k);
        uint8[] memory large = new uint8[](k);
        uint256 sLen;
        uint256 lLen;
        for (uint256 i = 0; i < k; ++i) {
            if (scaled[i] < PREC) small[sLen++] = uint8(i);
            else large[lLen++] = uint8(i);
        }

        uint256[] memory work = new uint256[](k);
        for (uint256 i = 0; i < k; ++i) work[i] = scaled[i];

        while (sLen > 0 && lLen > 0) {
            uint8 s = small[--sLen];
            uint8 l = large[--lLen];
            w.probFrac[s] = work[s];
            w.aliasIndex[s] = l;
            uint256 dec = PREC - work[s];
            work[l] = work[l] - dec;
            if (work[l] < PREC) small[sLen++] = l; else large[lLen++] = l;
        }
        while (lLen > 0) {
            uint8 i2 = large[--lLen];
            w.probFrac[i2] = PREC;
            w.aliasIndex[i2] = i2;
        }
        while (sLen > 0) {
            uint8 i3 = small[--sLen];
            w.probFrac[i3] = work[i3] > 0 ? work[i3] : PREC;
            w.aliasIndex[i3] = i3;
        }
    }

    function sampleIndex(Wave memory w, bytes32 seed) internal pure returns (uint8) {
        require(w.k > 0, "empty-wave");
        uint256 r = uint256(seed);
        uint256 col = r % uint256(w.k);
        uint256 frac = (r >> 128) % PREC;
        if (frac < w.probFrac[col]) return uint8(col);
        return w.aliasIndex[col];
    }

    function valueAt(Wave memory w, uint8 idx) internal pure returns (uint256) {
        require(idx < w.k, "idx-oob");
        return w.values[idx];
    }

    function expectedValue(Wave memory w) internal pure returns (uint256 exp) {
        for (uint256 i = 0; i < w.k; ++i) {
            exp += (w.values[i] * w.probFrac[i]) / PREC;
        }
    }

    function buildDegenerate(uint256 v) internal pure returns (Wave memory w) {
        w.k = 1;
        w.values = new uint256[](1);
        w.values[0] = v;
        w.probFrac = new uint256[](1);
        w.probFrac[0] = PREC;
        w.aliasIndex = new uint8[](1);
        w.aliasIndex[0] = 0;
    }
}

