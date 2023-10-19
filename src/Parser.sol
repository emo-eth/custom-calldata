// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

library Parser {
    uint256 constant _5_BIT_MASK = 0x1f;
    uint256 constant ONE_WORD = 32;
    uint256 constant BYTES_TO_BITS_SHIFT = 3;
    uint256 constant EXPAND_FLAG = 0x20;
    uint256 constant POINTER_FLAG = 0x40;
    uint256 constant POINTER_FLAG_OFFSET = 6;
    uint256 constant META_ARG_INDEX = 0;
    uint256 constant EXPAND_ARG_INDEX = 1;

    /**
     * @notice Read the first single encoded word from a calldata bytes array, assuming it is type 1
     * @param data The calldata bytes array from which to read
     * @return readValue
     * @return newPos
     * @return isPtr
     */
    function readSingleType1(bytes calldata data)
        internal
        pure
        returns (bytes32 readValue, uint256 newPos, bool isPtr)
    {
        uint256 pos;
        assembly {
            pos := data.offset
        }
        return readSingleType1(pos);
    }

    /**
     * @notice Read a single encoded word from calldata, assuming it is type 1
     * @param pos The calldata offset from which to read
     * @return val
     * @return newPos
     * @return isPtr
     */
    function readSingleType1(uint256 pos) internal pure returns (bytes32 val, uint256 newPos, bool isPtr) {
        assembly {
            // ptr?|0|size <value>
            // 0x0000 - encodes bytes32(0)
            // 0x011111 - encodes uint256(15)
            // 0x1f1000000000000000000000000000000000000000000000000000000000000000 encodes 1 << 255
            // 0x81ffff - encodes pointer(65535)

            // load encoded item from calldata at pos
            let temp := calldataload(pos)
            // get first byte of encoded item which encodes metadata
            let meta := byte(0, temp)
            // the last 5 bits represent number of bytes to read after this position, minus 1
            let numBytesToRead :=
                add(
                    // add 1 to last 5 bits to get number of bits to read
                    1,
                    // mask last 5 bits of meta
                    and(meta, _5_BIT_MASK)
                )
            // top bit of meta indicates whether the value is a pointer
            isPtr := shr(POINTER_FLAG_OFFSET, meta)
            let numExtraBytes := sub(ONE_WORD, numBytesToRead)
            // multiply by 8 to get number of bits to shr

            let readRightShift := shl(BYTES_TO_BITS_SHIFT, numExtraBytes)
            // read word from pos + 1
            newPos := add(pos, 1)
            val := calldataload(newPos)
            // shr by readRightShift to get rid of the bytes we don't want
            val := shr(readRightShift, val)
            newPos := add(newPos, numBytesToRead)
        }
    }

    /**
     * @notice Read the first  encoded word from a calldata bytes array, assuming it is type 2
     * @param data The calldata bytes array from which to read
     * @return readValue
     * @return newPos
     * @return isPtr
     */
    function readSingleType2(bytes calldata data)
        internal
        pure
        returns (bytes32 readValue, uint256 newPos, bool isPtr)
    {
        uint256 pos;
        assembly {
            pos := data.offset
        }
        return readSingleType2(pos);
    }

    /**
     * @notice Read a single encoded word from calldata, assuming it is type 2
     * @param pos The calldata offset from which to read
     * @return val
     * @return newPos
     * @return isPtr
     */
    function readSingleType2(uint256 pos) internal pure returns (bytes32 val, uint256 newPos, bool isPtr) {
        assembly {
            // ptr?|expand?|size expandBits? <value>
            // 0x 20 00 00 - encodes bytes32(0)
            // 0x 01 1111 - encodes uint256(15)
            // 0x 20 f8 80 encodes 1 << 255 or ((1 << 7) << (31 << 3))
            // 0x 60 08 01 - encodes pointer(256) or pointer(1 << (1 << 3))
            // load encoded item from calldata at pos
            let temp := calldataload(pos)
            // get first byte of word at position item which encodes metadata
            let meta := byte(META_ARG_INDEX, temp)
            // if EXPAND_FLAG is set, load second byte of encoded item which encodes expansion metadata
            let expandFlag := iszero(iszero(and(meta, EXPAND_FLAG)))
            let expandBits := mul(byte(EXPAND_ARG_INDEX, temp), expandFlag)
            // the last 5 bits represent number of bytes to read after this position, minus 1
            let numBytesEncoded :=
                add(
                    // add 1 to last 5 bits to get number of bytes to read
                    1,
                    // mask last 5 bits of meta
                    and(meta, _5_BIT_MASK)
                )
            // check if pointer flag is set
            isPtr := shr(POINTER_FLAG_OFFSET, meta)
            let numExtraBytesLoaded := sub(ONE_WORD, numBytesEncoded)
            // multiply by 8 to get number of bits to shr
            let readRightShift := shl(BYTES_TO_BITS_SHIFT, numExtraBytesLoaded)
            // read word from pos + 1 + expandFlag
            newPos := add(pos, add(1, expandFlag))
            val := calldataload(newPos)
            // shr by readRightShift to get rid of the bytes we don't want, then shl by expand to expand the bytes we do want
            val := shl(expandBits, shr(readRightShift, val))
            newPos := add(newPos, numBytesEncoded)
        }
    }

    /**
     * @notice Read the first encoded word from a calldata bytes array, automatically detecting whether it is type 1 or type 2
     * @param data The calldata to read from
     * @return readValue
     * @return newPos
     * @return isPtr
     */
    function readSingle(bytes calldata data) internal pure returns (bytes32 readValue, uint256 newPos, bool isPtr) {
        uint256 pos;
        assembly {
            pos := data.offset
        }
        return readSingle(pos);
    }

    /**
     * @notice Read a single encoded word from calldata, automatically detecting whether it is type 1 or type 2
     * @param pos Calldata offset from which to read
     * @return val
     * @return newPos
     * @return isPtr
     */
    function readSingle(uint256 pos) internal pure returns (bytes32 val, uint256 newPos, bool isPtr) {
        assembly {
            function readSingleType1(_meta, _pos) -> _val, _newPos, _isPtr {
                // ptr|0|size <value>
                // 0x0000 - encodes bytes32(0)
                // 0x011111 - encodes uint256(15)
                // 0x1f1000000000000000000000000000000000000000000000000000000000000000 encodes 1 << 255
                // 0x81ffff - encodes pointer(65535)

                // the last 5 bits represent number of bytes to read after this position, minus 1
                let numBytesToRead :=
                    add(
                        // add 1 to last 5 bits to get number of bits to read
                        1,
                        // mask last 5 bits of meta
                        and(_meta, _5_BIT_MASK)
                    )
                // top bit of meta indicates whether the value is a pointer
                _isPtr := shr(POINTER_FLAG_OFFSET, _meta)
                let numExtraBytes := sub(ONE_WORD, numBytesToRead)
                // multiply by 8 to get number of bits to shr

                let readRightShift := shl(BYTES_TO_BITS_SHIFT, numExtraBytes)
                // read word from pos + 1
                _newPos := add(_pos, 1)
                _val := calldataload(_newPos)
                // shr by readRightShift to get rid of the bytes we don't want
                _val := shr(readRightShift, _val)
                _newPos := add(_newPos, numBytesToRead)
            }
            function readSingleType2(_temp, _meta, _pos) -> _val, _newPos, _isPtr {
                // ptr|expand?|size expandBits? <value>
                // 0x 20 00 00 - encodes bytes32(0)
                // 0x 01 1111 - encodes uint256(15)
                // 0x 20 f8 80 encodes 1 << 255 or ((1 << 7) << (31 << 3))
                // 0x 60 08 01 - encodes pointer(256) or pointer(1 << (1 << 3))
                // load encoded item from calldata at pos
                // get first byte of word at position item which encodes metadata
                // if EXPAND_FLAG is set, load second byte of encoded item which encodes expansion metadata
                let expandBits := byte(EXPAND_ARG_INDEX, _temp)
                // the last 5 bits represent number of bytes to read after this position, minus 1
                // mask last 5 bits of meta
                let metaArg := and(_meta, _5_BIT_MASK)
                // if expandBits is 0,
                // let extendArg := add(iszero(iszero(expandBits)), metaArg)
                let numBytesEncoded :=
                    add(
                        // add 1 to last 5 bits to get number of bytes to read
                        1,
                        metaArg
                    )
                // check if pointer flag is set
                _isPtr := shr(POINTER_FLAG_OFFSET, _meta)
                let numExtraBytesLoaded := sub(ONE_WORD, numBytesEncoded)
                // multiply by 8 to get number of bits to shr
                let readRightShift := shl(BYTES_TO_BITS_SHIFT, numExtraBytesLoaded)
                // read word from pos + 1 + expandFlag
                _newPos := add(_pos, 2)
                _val := calldataload(_newPos)
                // shr by readRightShift to get rid of the bytes we don't want, then shl by expand to expand the bytes we do want
                _val := shl(expandBits, shr(readRightShift, _val))
                _newPos := add(_newPos, numBytesEncoded)
            }
            let temp := calldataload(pos)
            let meta := byte(0, temp)
            let type2 := and(meta, EXPAND_FLAG)
            for {} 1 {} {
                if iszero(type2) {
                    val, newPos, isPtr := readSingleType1(meta, pos)
                    break
                }
                val, newPos, isPtr := readSingleType2(temp, meta, pos)
                break
            }
        }
    }

    /**
     * @notice Read a word-aligned array from calldata
     * @dev temp, tentative
     * @param pos The calldata offset from which to read
     * @return result
     * @return newPos
     * @return isPtr
     */
    function readLiteralBytesArray(uint256 pos)
        internal
        pure
        returns (bytes calldata result, uint256 newPos, bool isPtr)
    {
        assembly {
            // load encoded item from calldata at pos
            let temp := calldataload(pos)
            // get first byte of encoded item which encodes metadata
            let meta := byte(0, temp)
            // the last 5 bits represent number of bytes to read after this position, minus 1
            let numBytesToRead :=
                add(
                    // add 1 to last 5 bits to get number of bits to read
                    1,
                    // mask last 5 bits of meta
                    and(meta, _5_BIT_MASK)
                )
            let numExtraBytes := sub(ONE_WORD, numBytesToRead)
            // multiply by 8 to get number of bits to shr
            let readRightShift := shl(BYTES_TO_BITS_SHIFT, numExtraBytes)
            // read word from pos + 1
            result.offset := add(pos, 1)
            result.length := calldataload(result.offset)
            // shr by readRightShift to get rid of the bytes we don't want
            result.length := shr(readRightShift, result.length)
            result.offset := add(result.offset, numBytesToRead)
            newPos := add(result.offset, result.length)
            isPtr := true
        }
    }

    function readWordArray(uint256 pos) internal pure returns (bytes32[] calldata result, uint256 newPos, bool isPtr) {
        {
            assembly {
                // load encoded item from calldata at pos
                let temp := calldataload(pos)
                // get first byte of encoded item which encodes metadata
                let meta := byte(0, temp)
                // the last 5 bits represent number of bytes to read after this position, minus 1
                let numBytesToRead :=
                    add(
                        // add 1 to last 5 bits to get number of bits to read
                        1,
                        // mask last 5 bits of meta
                        and(meta, _5_BIT_MASK)
                    )
                let numExtraBytes := sub(ONE_WORD, numBytesToRead)
                // multiply by 8 to get number of bits to shr
                let readRightShift := shl(BYTES_TO_BITS_SHIFT, numExtraBytes)
                // read word from pos + 1
                result.offset := add(pos, 1)
                result.length := calldataload(result.offset)
                // shr by readRightShift to get rid of the bytes we don't want
                result.length := shr(readRightShift, result.length)
                result.offset := add(result.offset, numBytesToRead)
                // multiply length by 32 to account for word size
                newPos := add(result.offset, shl(5, result.length))
                isPtr := true
            }
        }
    }
}
