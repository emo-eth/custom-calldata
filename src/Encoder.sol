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
    // a pointer will never point to an offset greater than 32 bits, ie, a POINTER will never require EXPANDing
    // so we can overload these two bits to indicate signed values by marking both the EXPAND and POINTER flags
    uint256 constant SIGNED_FLAG = 0x60;
    uint256 constant ARRAY_FLAG = 0x80;
    uint256 constant ARRAY_WORD_ELEMENTS_FLAG = 0x20;
    // uint256 constant ARRAY_POINTER_FLAG = 0x20;

    /**
     * @notice Encodes a bytes32 value into a bytes array according to the "Type1" schema
     *         Type1 is the concatenation of the following bytes: (VAL_WIDTH_BYTES - 1)<right-packed VAL>
     *         Type1 is marginally cheaper to decode than Type2, but will not compress the "right side" of the value.
     * @param x The bytes32 value to encode
     */
    function encodeType1(bytes32 x) internal pure returns (bytes memory encoded) {
        (uint256 valWidth, uint256 lengthAdjust, uint256 meta, bytes32 newVal) = type1Components(x);
        return encodeFromComponents(uint256(valWidth), uint256(lengthAdjust), uint256(meta), newVal);
    }

    /**
     * @notice Encodes a bytes32 value into a bytes array according to the "Type2" schema
     *         Type2 is the concatenation of the following bytes: ((VAL_WIDTH_BYTES - 1) | EXPAND_FLAG?)(EXPAND_BITS? or NULL)<packed VAL>
     *         Type2 will only encode expansion bits if it will save at least 4 bytes of zero calldata, otherwise, encoding a non-zero byte is more expensive;
     *         thus Type2 is a "superset" of Type1.
     *         Type2 is marginally more expensive to decode than Type1, but compresses the "right side" of values when economical to do so.
     * @param x The bytes32 value to encode
     */
    function encodeType2(bytes32 x) internal pure returns (bytes memory encoded) {
        (uint256 valWidth, uint256 lengthAdjust, uint256 meta, bytes32 y) = type2Components(x);
        return encodeFromComponents(uint256(valWidth), uint256(lengthAdjust), uint256(meta), y);
    }

    function encodeType3(bytes32 x) internal pure returns (bytes memory encoded) {
        return encodeType2(x);
    }

    function encodeType3(int256 x) internal pure returns (bytes memory encoded) {
        bool signed;
        bytes32 cast;
        assembly {
            signed := shr(255, x)
            cast := x
        }
        (uint256 valWidth, uint256 lengthAdjust, uint256 meta, bytes32 y) = type3Components(cast, signed);

        return encodeFromComponents(uint256(valWidth), uint256(lengthAdjust), uint256(meta), y);
    }

    /**
     * @notice Encodes a relative offset pointer into a bytes array according to the "Type1" schema
     *         (since a pointer will realistically never be more than 32 bytes)
     */
    function encodeRelativePointer(uint256 pos) internal pure returns (bytes memory encoded) {
        (uint256 valWidth, uint256 lengthAdjust, uint256 meta, bytes32 newVal) = type1Components(bytes32(pos));
        return encodeFromComponents(valWidth, lengthAdjust, meta | POINTER_FLAG, newVal);
    }

    function encodeArrayLiteralBytes(bytes memory input) internal pure returns (bytes memory encoded) {
        (uint256 valWidth, uint256 lengthAdjust, uint256 meta, bytes32 y) = type1Components(bytes32(input.length));

        // encode length efficiently
        bytes memory encodedLength = encodeFromComponents(valWidth, lengthAdjust, meta | ARRAY_FLAG, y);
        // but concat it with literal bytes from bytes array
        return bytes.concat(encodedLength, input);
    }

    function encodeArrayLiteralWords(bytes32[] memory input) internal pure returns (bytes memory encoded) {
        (uint256 valWidth, uint256 lengthAdjust, uint256 meta, bytes32 y) = type1Components(bytes32(input.length));

        // encode length efficiently
        bytes memory encodedLength =
            encodeFromComponents(valWidth, lengthAdjust, meta | ARRAY_FLAG | ARRAY_WORD_ELEMENTS_FLAG, y);
        // but concat it with literal words from bytes array
        return bytes.concat(encodedLength, abi.encodePacked(input));
    }

    function encodeArrayCompact(bytes32[] memory input) internal pure returns (bytes memory encoded) {
        uint256 length = input.length;
        (uint256 valWidth, uint256 lengthAdjust, uint256 meta, bytes32 y) = type1Components(bytes32(length));

        // encode length efficiently
        encoded = encodeFromComponents(valWidth, lengthAdjust, meta | ARRAY_FLAG, y);
        // then encode each element efficiently
        for (uint256 i; i < length; i++) {
            encoded = bytes.concat(encoded, encodeType2(input[i]));
        }
        return encoded;
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

    function type3Components(bytes32 x, bool sign)
        internal
        pure
        returns (uint256 valWidth, uint256 metaWidth, uint256 meta, bytes32 newVal)
    {
        unchecked {
            uint256 expansionBits = lsb(uint256(x));
            uint256 flags;

            uint256 notMul;
            uint256 mulMul;

            assembly {
                // 0 if expansionBits <= 32, otherwise expansionBits
                expansionBits := mul(expansionBits, lt(expansionBits, 32))

                // shr or sar depending on sign
                newVal :=
                    or(
                        // if sign is true, sar by expansionBits
                        mul(sign, sar(expansionBits, x)),
                        // if sign is false, shr by expansionBits
                        mul(iszero(sign), shr(expansionBits, x))
                    )

                notMul := mul(sign, not(newVal))
                mulMul := mul(iszero(sign), newVal)

                // if sign is true, then we need to flip all bits to determine how many bytes to cut off top
                newVal := or(mul(sign, not(newVal)), mul(iszero(sign), newVal))
                flags := or(EXPAND_FLAG, shl(sign, EXPAND_FLAG))
            }

            valWidth = (msb(uint256(newVal)) >> BITS_TO_BYTES_SHIFT) + 1;
            metaWidth = 2;
            meta = (((valWidth - 1) | flags) << ONE_BYTE_BITS) | expansionBits;
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
