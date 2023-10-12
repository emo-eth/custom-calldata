// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract Parser {
    uint256 constant _5_BIT_MASK = 0x1f;
    uint256 constant ONE_WORD = 32;
    uint256 constant BYTES_TO_BITS_SHIFT = 3;
    uint256 constant EXPAND_FLAG = 0x20;
    uint256 constant POINTER_FLAG = 0x40;
    uint256 constant META_ARG_INDEX = 0;
    uint256 constant EXPAND_ARG_INDEX = 1;

    function readSingle(bool type2, bytes calldata data) public pure returns (bytes32 readValue) {
        assembly {
            // TODO: handle calldatacopying arbitrary bytes
            // TODO: handle traditional calldata bytesarrays

            function decodeType1(pos) -> val, isPtr, newPos {
                // ptr|0|size <value>
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
                isPtr := iszero(iszero(and(meta, POINTER_FLAG)))
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

            function decodeType2(pos) -> val, isPtr, newPos {
                // ptr|expand?|size expandBits? <value>
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
                isPtr := iszero(iszero(and(meta, POINTER_FLAG)))
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

            function readWordAlignedArray(pos) -> length, offset {
                // ptr|size <value>
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
                let numExtraBytes := sub(ONE_WORD, numBytesToRead)
                // multiply by 8 to get number of bits to shr
                let readRightShift := shl(BYTES_TO_BITS_SHIFT, numExtraBytes)
                // read word from pos + 1
                offset := add(pos, 1)
                length := calldataload(offset)
                // shr by readRightShift to get rid of the bytes we don't want, then shl by expand to expand the bytes we do want
                length := shr(readRightShift, length)
                offset := add(offset, numBytesToRead)
            }

            // actual logic

            let isPtr, newPos
            if type2 {
                readValue, isPtr, newPos := decodeType2(data.offset)
                mstore(0, readValue)
                return(0, 0x20)
            }
            readValue, isPtr, newPos := decodeType1(data.offset)
            mstore(0, readValue)
            return(0, 0x20)
        }
    }
}
