// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";

library XRLPEncoder {
    uint256 constant IDENTITY_PRECOMPILE = 0x04;
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
    uint256 constant TYPE_ZERO = 0;
    uint256 constant TYPE_ONE_MIN = 0x80; // 0b10000000
    uint256 constant TYPE_ONE_MAX = 0x9f; // 0b10011111
    uint256 constant TYPE_TWO_MIN = 0xa0; // 0b10100000
    uint256 constant TYPE_TWO_MAX = 0xbf; // 0b10111111
    uint256 constant TYPE_THREE_MIN = 0xc0; // 0b11000000
    uint256 constant TYPE_THREE_MAX = 0xdf; // 0b11011111
    uint256 constant BYTES_MIN = 0xe0; // 0b11100000
    uint256 constant BYTES_MAX = 0xe3; // 0b11100011
    uint256 constant WORDS_MIN = 0xe4; // 0b11100100
    uint256 constant WORDS_MAX = 0xe7; // 0b11100111
    uint256 constant HOMOGENOUS_NBYTE_MIN = 0xe8; // 0b11101000
    uint256 constant HOMOGENOUS_NBYTE_MAX = 0xeb; // 0b11101011
    uint256 constant HETEROGENOUS_NBYTE_MIN = 0xec; // 0b11101100
    uint256 constant HETEROGENOUS_NBYTE_MAX = 0xef; // 0b11101111
    uint256 constant ARRAYS_MIN = 0xe0; // 0b11100000
    uint256 constant ARRAYS_MAX = 0xef; // 0b11101111
    uint256 constant WORD_REG_MIN = 0xf0; // 0b11110000
    uint256 constant WORD_REG_MAX = 0xf3; // 0b11110011
    uint256 constant BYTES_REG_MIN = 0xf4; // 0b11110100
    uint256 constant BYTES_REG_MAX = 0xf7; // 0b11110111
    uint256 constant REG_MIN = 0xf0; // 0b11110000
    uint256 constant REG_MAX = 0xf7; // 0b11110111
    uint256 constant NESTED_MIN = 0xf8; // 0b11111000
    uint256 constant NESTED_MAX = 0xfb; // 0b11111011
    uint256 constant EIP2098_SIG = 0xfc; // 0b11111100
    uint256 constant POINTER_TWO_BYTE = 0xfd; // 0b11111101
    uint256 constant POINTER_FOUR_BYTE = 0xfe; // 0b11111110
    uint256 constant RESERVED = 0xff; // 0b11111111

    function encode(bytes32 val) internal pure returns (bytes memory encoded) {
        uint256 x = uint256(val);
        if (x < TYPE_ONE_MIN) {
            return abi.encodePacked(uint8(x));
        }

        (uint256 valWidth, uint256 prefixWidth, uint256 prefix, bytes32 newVal) = type1Components(val);
        (uint256 valWidth2, uint256 prefixWidth2, uint256 prefix2, bytes32 newVal2) = type2Components(val);
        (uint256 valWidth3, uint256 prefixWidth3, uint256 prefix3, bytes32 newVal3) = type3Components(val);
        uint256 type1Length = valWidth + prefixWidth;
        uint256 type2Length = valWidth2 + prefixWidth2;
        uint256 type3Length = valWidth3 + prefixWidth3;
        if (type1Length <= type2Length && type1Length <= type3Length) {
            return encodeFromComponents(valWidth, prefixWidth, prefix, newVal);
        } else if (type2Length <= type1Length && type2Length <= type3Length) {
            return encodeFromComponents(valWidth2, prefixWidth2, prefix2, newVal2);
        } else {
            return encodeFromComponents(valWidth3, prefixWidth3, prefix3, newVal3);
        }
    }

    function encode(bytes memory arr) internal pure returns (bytes memory encoded) {
        uint256 arrLengthBytesWidthMinusOne = (msb(arr.length) >> BITS_TO_BYTES_SHIFT);
        require(arrLengthBytesWidthMinusOne < 4, "XRLPEncoder: array too long");
        uint256 prefix = (arrLengthBytesWidthMinusOne) | BYTES_MIN;
        if (arrLengthBytesWidthMinusOne == 0) {
            return abi.encodePacked(uint8(prefix), uint8(arr.length), arr);
        } else if (arrLengthBytesWidthMinusOne == 1) {
            return abi.encodePacked(uint8(prefix), uint16(arr.length), arr);
        } else if (arrLengthBytesWidthMinusOne == 2) {
            return abi.encodePacked(uint8(prefix), uint24(arr.length), arr);
        } else {
            return abi.encodePacked(uint8(prefix), uint32(arr.length), arr);
        }
    }

    function encode(bytes32[] memory arr) internal pure returns (bytes memory encoded) {
        uint256 arrLengthBytesWidthMinusOne = (msb(arr.length) >> BITS_TO_BYTES_SHIFT);
        require(arrLengthBytesWidthMinusOne < 4, "XRLPEncoder: array too long");
        uint256 prefix = (arrLengthBytesWidthMinusOne) | WORDS_MIN;
        if (arrLengthBytesWidthMinusOne == 0) {
            return abi.encodePacked(uint8(prefix), uint8(arr.length), (arr));
        } else if (arrLengthBytesWidthMinusOne == 1) {
            return abi.encodePacked(uint8(prefix), uint16(arr.length), (arr));
        } else if (arrLengthBytesWidthMinusOne == 2) {
            return abi.encodePacked(uint8(prefix), uint24(arr.length), (arr));
        } else {
            return abi.encodePacked(uint8(prefix), uint32(arr.length), (arr));
        }
    }

    function encode(bytes32[] memory arr, uint256 width, uint256 expansionBits)
        internal
        pure
        returns (bytes memory encoded)
    {
        uint256 arrLengthBytesWidthMinusOne = (msb(arr.length) >> BITS_TO_BYTES_SHIFT);
        require(arrLengthBytesWidthMinusOne < 4, "XRLPEncoder: array too long");
        uint256 meta = (
            ((arrLengthBytesWidthMinusOne | HOMOGENOUS_NBYTE_MIN) << 16 | (width << 8) | expansionBits)
                << ((arrLengthBytesWidthMinusOne + 1) << BITS_TO_BYTES_SHIFT) | arr.length
        );

        assembly {
            encoded := mload(0x40)
            // get actual length of array
            let arrLength := mload(arr)
            // get actual bytes width of array length
            let arrLengthBytesWidth := add(arrLengthBytesWidthMinusOne, 1)
            // meta + width + expand + length
            let metaPlusLengthWidth := add(3, arrLengthBytesWidth)
            // get length of final array
            let encodedLength := add(metaPlusLengthWidth, mul(arrLength, width))
            // start writing at the end of the encoded array so subsequent writes
            // do not overwrite previous ones
            let writePointer :=
                add(
                    // skip length
                    ONE_WORD,
                    // get pointer to the very end
                    add(encoded, encodedLength)
                )
            // start reading from the last element of the array
            let readPointer := add(add(arr, 0x20), shl(5, arrLength))

            for { let i := 0 } lt(i, arrLength) {
                // iterate over each element i
                i := add(i, 1)
                // subtract a word from the read pointer to get previous element
                readPointer := sub(0x20, readPointer)
                // subtract width from write pointer to get previous element
                writePointer := sub(writePointer, width)
            } {
                // load element from read pointer, write to write pointer
                mstore(writePointer, shr(expansionBits, mload(readPointer)))
            }
            // write meta + width + expand + length
            mstore(add(encoded, metaPlusLengthWidth), meta)
            // store length
            mstore(encoded, encodedLength)
            // allocate memory so that it is word-aligned
            mstore(
                0x40,
                add(
                    encoded,
                    // round up to nearest word
                    shl(5, shr(5, add(encodedLength, 0x1f)))
                )
            )
        }
    }

    function encodeHeterogenous(bytes32[] memory arr) internal view returns (bytes memory encoded) {
        uint256 arrLengthBytesWidthMinusOne = (msb(arr.length) >> BITS_TO_BYTES_SHIFT);
        require(arrLengthBytesWidthMinusOne < 4, "XRLPEncoder: array too long");
        uint256 meta = (
            (HETEROGENOUS_NBYTE_MIN | arrLengthBytesWidthMinusOne)
                << ((arrLengthBytesWidthMinusOne + 1) << BITS_TO_BYTES_SHIFT)
        ) | arr.length;
        encoded = abi.encodePacked(uint8(meta));
        for (uint256 i; i < arr.length; ++i) {
            encoded = bytes.concat(encoded, encode(arr[i]));
        }
        return encoded;
    }

    function encodeWordFromRegistry(uint256 id) internal pure returns (bytes memory encoded) {
        return encodeFromRegistry(id, WORD_REG_MIN);
    }

    function encodeBytesFromRegistry(uint256 id) internal pure returns (bytes memory encoded) {
        return encodeFromRegistry(id, BYTES_REG_MIN);
    }

    function encodeFromRegistry(uint256 id, uint256 registryPrefix) internal pure returns (bytes memory encoded) {
        uint256 idWidth = bytesWidth(id);
        require(idWidth < 7, "XRLPEncoder: id too large");
        uint256 encodedWidth;
        if (idWidth < 3) {
            encodedWidth = 0;
        } else {
            encodedWidth = idWidth - 3;
        }
        if (encodedWidth == 0) {
            return abi.encodePacked(uint8(registryPrefix), uint24(id));
        } else if (encodedWidth == 1) {
            return abi.encodePacked(uint8(registryPrefix | 1), uint32(id));
        } else if (encodedWidth == 2) {
            return abi.encodePacked(uint8(registryPrefix | 2), uint40(id));
        } else {
            return abi.encodePacked(uint8(registryPrefix | 3), uint48(id));
        }
    }

    function encodeNested(bytes memory xrlpData) internal pure returns (bytes memory encoded) {
        uint256 lengthBytesWidthMinusOne = bytesWidth(xrlpData.length) - 1;
        require(lengthBytesWidthMinusOne < 4, "XRLPEncoder: array too long");
        uint256 prefix = (
            (lengthBytesWidthMinusOne | NESTED_MIN) << ((lengthBytesWidthMinusOne + 1) << BITS_TO_BYTES_SHIFT)
        ) | xrlpData.length;
        if (lengthBytesWidthMinusOne == 0) {
            return abi.encodePacked(uint8(prefix), uint8(xrlpData.length), xrlpData);
        } else if (lengthBytesWidthMinusOne == 1) {
            return abi.encodePacked(uint8(prefix), uint16(xrlpData.length), xrlpData);
        } else if (lengthBytesWidthMinusOne == 2) {
            return abi.encodePacked(uint8(prefix), uint24(xrlpData.length), xrlpData);
        } else {
            return abi.encodePacked(uint8(prefix), uint32(xrlpData.length), xrlpData);
        }
    }

    function encodeEip2098(bytes32 r, bytes32 s, uint8 v) internal pure returns (bytes memory encoded) {
        uint8 yParity = (v % 2) == 1 ? 1 : 0;
        bytes32 yParityAndS = bytes32(uint256(s) | (uint256(yParity) << 255));
        return encodeEip2098(abi.encodePacked(r, yParityAndS));
    }

    function encodeEip2098(bytes memory sig) internal pure returns (bytes memory encoded) {
        require(sig.length == 64, "XRLPEncoder: invalid EIP-2908 signature");
        return abi.encodePacked(uint8(EIP2098_SIG), sig);
    }

    function encodePointer(uint256 offset) internal pure returns (bytes memory encoded) {
        uint256 offsetWidthMinusOne = bytesWidth(offset) - 1;
        require(offsetWidthMinusOne < 4, "XRLPEncoder: offset too large");

        if (offsetWidthMinusOne < 2) {
            return abi.encodePacked(uint8(POINTER_TWO_BYTE), uint16(offset));
        } else {
            return abi.encodePacked(uint8(POINTER_FOUR_BYTE), uint32(offset));
        }
    }

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

    /**
     * @notice Returns the components of a Type1 encoding for a given value
     * @param x The bytes32 value to encode
     * @return valWidth
     * @return prefixWidth
     * @return meta
     * @return newVal
     */
    function type1Components(bytes32 x)
        private
        pure
        returns (uint256 valWidth, uint256 prefixWidth, uint256 meta, bytes32 newVal)
    {
        unchecked {
            valWidth = (msb(uint256(x)) >> BITS_TO_BYTES_SHIFT) + 1;
            prefixWidth = 1;
            meta = valWidth - 1;
            newVal = x;
        }
    }

    /**
     * @notice Returns the components of a Type2 encoding for a given value
     * @param x The bytes32 value to get encoding components for
     * @return valWidth
     * @return prefixWidth
     * @return prefix
     * @return newVal
     */
    function type2Components(bytes32 x)
        internal
        pure
        returns (uint256 valWidth, uint256 prefixWidth, uint256 prefix, bytes32 newVal)
    {
        unchecked {
            uint256 expansionBits = lsb(uint256(x));
            if (expansionBits < EXPANSION_BIT_CUTOFF) {
                return type1Components(x);
            }
            newVal = bytes32(uint256(x) >> expansionBits);
            valWidth = (msb(uint256(newVal)) >> BITS_TO_BYTES_SHIFT) + 1;
            prefixWidth = 2;
            prefix = (((valWidth - 1) | TYPE_TWO_MIN) << ONE_BYTE_BITS) | expansionBits;
        }
    }

    function type3Components(bytes32 x)
        internal
        pure
        returns (uint256 valWidth, uint256 prefixWidth, uint256 prefix, bytes32 newVal)
    {
        unchecked {
            uint256 expansionBits = lsb(uint256(x));
            uint256 flags;

            uint256 notMul;
            uint256 mulMul;

            assembly {
                // check top bit to see if it should be treated as signed
                let sign := shr(255, x)
                // 0 if expansionBits <= 32, otherwise expansionBits
                expansionBits := mul(expansionBits, lt(expansionBits, 32))
                // signed arithmetic right shift (sar) will fill the top bits with the sign bit if present
                newVal := sar(expansionBits, x)
                // if sign is true, then we need to flip all bits to determine how many bytes to cut off top
                // 0 if sign is false.
                notMul := mul(sign, not(newVal))
                // if sign is false, use newVal without modification
                // 0 if sign is true.
                mulMul := mul(iszero(sign), newVal)

                // get the non-zero value
                newVal := or(notMul, mulMul)
                flags := TYPE_THREE_MIN
            }

            valWidth = (msb(uint256(newVal)) >> BITS_TO_BYTES_SHIFT) + 1;
            prefixWidth = 2;
            prefix = (((valWidth - 1) | flags) << ONE_BYTE_BITS) | expansionBits;
        }
    }

    /**
     *
     * @param valWidth The width in bytes of the value to encode
     * @param prefixWidth The width in bytes of the encoding meta
     * @param prefix The encoding meta value
     * @param val The bytes32 value to encode
     */
    function encodeFromComponents(uint256 valWidth, uint256 prefixWidth, uint256 prefix, bytes32 val)
        internal
        pure
        returns (bytes memory encoded)
    {
        assembly {
            // assign encoded to free memory pointer
            encoded := mload(FREE_PTR)
            // allocate memory so that it is word-aligned
            let bytesToAllocate := add(TWO_WORDS, and(valWidth, ONE_WORD))
            // actual length of the bytes array is the sum of the meta width and the value width
            let byteArrayLength := add(prefixWidth, valWidth)
            // update free memory pointer by up to 3 words
            mstore(FREE_PTR, add(bytesToAllocate, encoded))
            // store y after length and meta
            mstore(add(encoded, byteArrayLength), val)
            // store the meta var in the byte(s) immediately after the bytes array length
            mstore(add(encoded, prefixWidth), prefix)
            // store array length
            mstore(encoded, byteArrayLength)
        }
    }

    function bytesWidth(uint256 x) internal pure returns (uint256) {
        return (msb(x) >> BITS_TO_BYTES_SHIFT) + 1;
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
