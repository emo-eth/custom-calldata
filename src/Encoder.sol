// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

library Encoder {
    uint256 constant EXPANSION_BIT_CUTOFF = 32; // 4 bytes
    uint256 constant BITS_TO_BYTES_ROUND_UP = 7;
    uint256 constant BITS_TO_BYTES_SHIFT = 3;
    uint256 constant FREE_PTR = 0x40;
    uint256 constant ONE_WORD = 0x20;
    uint256 constant TWO_WORDS = 0x40;
    uint256 constant TYPE1_META_OFFSET = 1;
    uint256 constant TYPE2_META_OFFSET = 2;
    uint256 constant TYPE1_LENGTH_ADJUST = 1;
    uint256 constant TYPE2_LENGTH_ADJUST = 2;
    uint256 constant ONE_BYTE_BITS = 8;
    uint256 constant EXPAND_FLAG = 0x20;
    uint256 constant POINTER_FLAG = 0x40;

    /**
     * @notice Encodes a bytes32 value into a bytes array according to the "Type1" schema
     *         Type1 is the concatenation of the following bytes: (VAL_WIDTH_BYTES - 1)<right-packed VAL>
     * @param x The bytes32 value to encode
     */
    function encodeType1(bytes32 x) internal pure returns (bytes memory encoded) {
        (uint256 valWidth, uint256 lengthAdjust, uint256 meta, bytes32 newVal) = type1Components(x);
        return encodeFromComponents(uint256(valWidth), uint256(lengthAdjust), uint256(meta), newVal);
    }

    /**
     * @notice Encodes a bytes32 value into a bytes array according to the "Type2" schema
     *         Type1 is the concatenation of the following bytes: ((VAL_WIDTH_BYTES - 1) | EXPAND_FLAG?)(EXPAND_BITS? or NULL)<packed VAL>
     * @param x The bytes32 value to encode
     */
    function encodeType2(bytes32 x) internal pure returns (bytes memory encoded) {
        (uint256 valWidth, uint256 lengthAdjust, uint256 meta, bytes32 y) = type2Components(x);
        return encodeFromComponents(uint256(valWidth), uint256(lengthAdjust), uint256(meta), y);
    }

    /**
     * @notice Returns the components of a Type1 encoding for a given value
     * @param x The bytes32 value to encode
     * @return valWidth
     * @return metaWidth
     * @return meta
     * @return newVal
     */
    function type1Components(bytes32 x)
        private
        pure
        returns (uint256 valWidth, uint256 metaWidth, uint256 meta, bytes32 newVal)
    {
        unchecked {
            valWidth = (msb(uint256(x)) >> BITS_TO_BYTES_SHIFT) + 1;
            metaWidth = 1;
            meta = valWidth - 1;
            newVal = x;
        }
    }

    /**
     * @notice Returns the components of a Type2 encoding for a given value
     * @param x The bytes32 value to get encoding components for
     * @return valWidth
     * @return metaWidth
     * @return meta
     * @return newVal
     */
    function type2Components(bytes32 x)
        internal
        pure
        returns (uint256 valWidth, uint256 metaWidth, uint256 meta, bytes32 newVal)
    {
        unchecked {
            uint256 expansionBits = lsb(uint256(x));
            if (expansionBits < EXPANSION_BIT_CUTOFF) {
                return type1Components(x);
            }
            newVal = bytes32(uint256(x) >> expansionBits);
            valWidth = (msb(uint256(newVal)) >> BITS_TO_BYTES_SHIFT) + 1;
            metaWidth = 2;
            meta = (((valWidth - 1) | EXPAND_FLAG) << ONE_BYTE_BITS) | expansionBits;
        }
    }

    /**
     *
     * @param valWidth The width in bytes of the value to encode
     * @param metaWidth The width in bytes of the encoding meta
     * @param meta The encoding meta value
     * @param y The bytes32 value to encode
     */
    function encodeFromComponents(uint256 valWidth, uint256 metaWidth, uint256 meta, bytes32 y)
        internal
        pure
        returns (bytes memory encoded)
    {
        assembly {
            // assign encoded to free memory pointer
            encoded := mload(FREE_PTR)
            let bytesToAllocate := add(TWO_WORDS, and(valWidth, ONE_WORD))
            let byteArrayLength := add(metaWidth, valWidth)
            // update free memory pointer by up to 3 words
            mstore(FREE_PTR, add(bytesToAllocate, encoded))
            // store y after length and meta
            mstore(add(encoded, byteArrayLength), y)
            // store the meta var in the byte(s) immediately after the bytes array length
            mstore(add(encoded, metaWidth), meta)
            // store array length
            mstore(encoded, byteArrayLength)
        }
    }

    /**
     * @notice Finds the most significant bit of a uint256
     * @param x Value to find the most significant bit of
     */
    function msb(uint256 x) internal pure returns (uint256) {
        // msb is equivalent of log2
        return FixedPointMathLib.log2(x);
    }

    /**
     * @notice Finds the least significant bit of a uint256
     * @param x Value to find the least significant bit of
     */
    function lsb(uint256 x) internal pure returns (uint256) {
        uint256 y;
        assembly {
            // mask out all bits except the least significant bit
            y := and(x, sub(0, x))
        }
        // get the position of the remaining bit
        return FixedPointMathLib.log2(y);
    }
}
