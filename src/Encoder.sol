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

    function encodeType1(bytes32 x) internal pure returns (bytes memory encoded) {
        // get number of bytes width for x
        uint256 bitWidth = msb(uint256(x));
        // range(0, 32]
        uint256 byteWidth = (bitWidth >> BITS_TO_BYTES_SHIFT) + 1;
        return _encodeType1(x, byteWidth);
    }

    function _encodeType1(bytes32 x, uint256 byteWidth) private pure returns (bytes memory encoded) {
        assembly {
            // get pointer to encoded
            encoded := mload(FREE_PTR)
            // update free memory pointer by up to 3 words
            // 1 for encoded length, 1 for first 32 bytes, optionally 1 for extra byte
            // bytesToAllocate = (byteWidth == 32) ? 0x60 : 0x40
            let bytesToAllocate := add(TWO_WORDS, and(byteWidth, ONE_WORD))
            mstore(FREE_PTR, add(bytesToAllocate, encoded))

            let bytesArrayLength := add(TYPE1_LENGTH_ADJUST, byteWidth)
            // store x after length with one extra byte of padding for the
            // meta var
            mstore(add(encoded, bytesArrayLength), x)

            // store the meta var in the byte immediately after the bytes array length
            mstore(
                add(encoded, TYPE1_META_OFFSET),
                // (bytewidth == 0) ? 0 : bytewidth - 1
                // bytewidth - 1
                sub(byteWidth, 1)
            )
            // store array length
            mstore(encoded, bytesArrayLength)
        }
    }

    function encodeType2(bytes32 x) internal pure returns (bytes memory encoded) {
        uint256 expansionBits = lsb(uint256(x));

        uint256 bitWidth = msb(uint256(x));
        uint256 byteWidth = ((bitWidth - expansionBits) >> BITS_TO_BYTES_SHIFT + 1);
        // don't encode expansion bits if it is more expensive than including all zero-bytes
        // eg, 1 non-zero byte is as expensive as 4 zero-bytes
        if (expansionBits < EXPANSION_BIT_CUTOFF) {
            // recalculate byteWidth
            byteWidth = (bitWidth + BITS_TO_BYTES_ROUND_UP) >> BITS_TO_BYTES_SHIFT;
            return _encodeType1(x, byteWidth);
        }
        assembly {
            let packedX := shr(expansionBits, x)

            // get pointer to encoded
            encoded := mload(FREE_PTR)
            // update free memory pointer by 2 words
            // 1 for encoded length, 1 for first 32 bytes, optionally 1 for extra byte
            // bytesToAllocate = (byteWidth == 32) ? 0x60 : 0x40
            let bytesToAllocate := add(TWO_WORDS, and(byteWidth, ONE_WORD))
            mstore(FREE_PTR, add(bytesToAllocate, encoded))

            let bytesArrayLength := add(TYPE2_LENGTH_ADJUST, byteWidth)
            // store x after length with one extra byte of padding for the
            // meta var
            mstore(add(encoded, bytesArrayLength), packedX)
            // store the expansion bits in the second byte immediately after the bytes array length
            // store the meta var in the 2 bytes immediately after the bytes array length

            mstore(
                add(encoded, TYPE2_META_OFFSET),
                // meta var is 2 bytes; first byte is (byteWidth - 1 or 0), second is expansionBits
                or(
                    // shift left by one byte
                    shl(ONE_BYTE_BITS, sub(byteWidth, 1)),
                    expansionBits
                )
            )
            // store array length
            mstore(encoded, bytesArrayLength)
        }
    }

    function msb(uint256 x) internal pure returns (uint256) {
        return FixedPointMathLib.log2(x);
    }

    function lsb(uint256 x) internal pure returns (uint256 y) {
        assembly {
            y := and(x, sub(0, x))
        }
        return FixedPointMathLib.log2(y);
    }
}
