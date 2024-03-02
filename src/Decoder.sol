// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Decoder {
    // pragma definition
    // [pragma byte, XRLP-encoded element-length, ]

    // 0-127 literal
    uint256 constant MAX_LIKE_0XXXXXXX = 0x80;
    // left-compact > 127
    // [schema + byte_width, <byte_width> bytes]
    uint256 constant MAX_LIKE_100XXXXX = 0xa0;
    // left + right compact > 127
    // [schema + byte_width, left_shift, <byte_width> bytes]
    uint256 constant MAX_LIKE_101XXXXX = 0xc0;
    // left + right compact negative or F-heavy bytesN
    // [schema + byte_width, left_shift, <byte_width> bytes]
    uint256 constant MAX_LIKE_110XXXXX = 0xe0;
    // bytearray/string
    // [schema + length_width, length, <length> bytes]
    uint256 constant MAX_LIKE_111000XX = 0xe4;
    // word-array
    // [schema + length_width, length, <length> words]
    uint256 constant MAX_LIKE_111001XX = 0xe8;
    // homogenous NByte-array
    // [schema + length_width, element_byte_width, left_shift, length, <length> NByte elements]
    uint256 constant MAX_LIKE_111010XX = 0xec;
    // XRLP-encoded array: heterogenous NByte, Struct[]
    // [schema + bytes_length_width, byte1_elem_length, byte2_elem_length, bytes_length, <length> bytes]
    uint256 constant MAX_LIKE_111011XX = 0xf0;
    // XRLP-encoded object: Struct
    // [schema + length_width, num_fields, bytes_length, <bytes_length> bytes]
    uint256 constant MAX_LIKE_111100XX = 0xf4;
    // Pointer
    // [schema + byte_width, <byte_width> pointer]
    uint256 constant MAX_LIKE_111101XX = 0xf8;
    // Stateful Registry ID
    // [schema + byte_width - 1, <byte_width> registry_id]
    uint256 constant MAX_LIKE_111110XX = 0xfc;
    // XRLP-encoded object to abi-encode..?
    uint256 constant LIKE_11111100 = 0xfc;
    uint256 constant LIKE_11111101 = 0xfd;
    uint256 constant LIKE_11111110 = 0xfe;
    // reserved
    uint256 constant LIKE_11111111 = 0xff;

    uint256 constant VALUE_WIDTH_MASK = 0x1f;
    uint256 constant LENGTH_MASK = 0x3;

    fallback(bytes calldata data) external returns (bytes memory decoded) {
        assembly ("memory-safe") {
            // function decode0xxxxxxx()
            function copyNByteArray(pos, bytesWidth, leftShift, numElems, absStart, freePtr) ->
                val,
                nextPos,
                nextFreePtr
            {
                let dest := freePtr
                // write the length of the array to memory
                mstore(dest, numElems)
                dest := add(dest, 0x20)
                let rightShift := sub(256, shl(bytesWidth, 3))
                // todo: unroll loops
                for { let i } lt(i, numElems) {
                    i := add(i, 1)
                    pos := add(pos, bytesWidth)
                    dest := add(0x20, dest)
                } {
                    let elem := shl(leftShift, shr(rightShift, calldataload(pos)))
                    mstore(dest, elem)
                }
                mstore(0x40, dest)
                val := sub(freePtr, absStart)
                nextPos := pos
                nextFreePtr := dest
            }
            function parse(pos, absStart, memIdx, freePtr) -> val, nextPos, nextFreePtr {
                let indexWord := calldataload(pos)
                let schemaByte := byte(0, indexWord)
                // 0-127 literal
                if lt(schemaByte, MAX_LIKE_0XXXXXXX) {
                    // schemaByte is literal value
                    val := schemaByte
                    // next position to read from is current position + 1
                    nextPos := add(pos, 1)
                    // return the values
                    leave
                }
                // left-compact > 127
                if lt(schemaByte, MAX_LIKE_100XXXXX) {
                    // get byteWidth of value to load by masking schemaByte and adding 1
                    let byteWidth := add(1, and(schemaByte, VALUE_WIDTH_MASK))
                    // calculate right shift to apply to loaded value
                    let rightShift := sub(256, shl(byteWidth, 3))
                    // load value from calldata and apply right shift
                    pos := add(1, pos)
                    val := shr(rightShift, calldataload(pos))
                    // calculate next position to read from
                    nextPos := add(pos, byteWidth)
                    // return the values
                    leave
                }
                // left + right compact
                if lt(schemaByte, MAX_LIKE_101XXXXX) {
                    // get byteWidth of value to load by masking schemaByte and adding 1
                    let byteWidth := add(1, and(schemaByte, VALUE_WIDTH_MASK))
                    // calculate right shift to apply to loaded value
                    let rightShift := sub(256, shl(byteWidth, 3))
                    // load value to left shift from calldata
                    let leftShift := byte(1, indexWord)
                    // load value from calldata and apply right shift
                    pos := add(2, pos)
                    val := shl(leftShift, shr(rightShift, calldataload(pos)))
                    // calculate next position to read from
                    nextPos := add(pos, byteWidth)
                    // return the values
                    leave
                }
                // negative or F-heavy bytesN
                if lt(schemaByte, MAX_LIKE_110XXXXX) {
                    // get byteWidth of value to load by masking schemaByte and adding 1
                    let byteWidth := add(1, and(schemaByte, VALUE_WIDTH_MASK))
                    // calculate right shift to apply to loaded value
                    let rightShift := sub(256, shl(byteWidth, 3))
                    // load value to left shift from calldata
                    let leftShift := byte(1, indexWord)
                    // load value from calldata and apply right shift
                    pos := add(2, pos)
                    val := shl(leftShift, not(shr(rightShift, calldataload(pos))))
                    // calculate next position to read from
                    nextPos := add(pos, byteWidth)
                    // return the values
                    leave
                }
                // bytes array
                if lt(schemaByte, MAX_LIKE_111000XX) {
                    // get lengthWidth of value to load by masking schemaByte and adding 1
                    let lengthWidth := add(1, and(schemaByte, LENGTH_MASK))
                    // calculate right shift to apply to loaded length
                    let rightShift := sub(256, shl(lengthWidth, 3))
                    // load length from calldata
                    pos := add(1, pos)
                    let length := shr(rightShift, calldataload(pos))
                    let dest := freePtr
                    // store length at freePtr
                    mstore(dest, length)
                    // calculate word-aligned length for next freePtr
                    let alignedLength := shl(5, shr(5, add(0x1f, length)))
                    dest := add(freePtr, 0x20)
                    pos := add(pos, lengthWidth)
                    // copy the data from calldata to memory
                    calldatacopy(dest, pos, length)
                    // calculate abi-encoded relative offset to store at memIdx
                    val := sub(freePtr, absStart)
                    // calculate next position to read from
                    nextPos := add(pos, length)
                    nextFreePtr := add(dest, alignedLength)
                    // increment and update freePtr to maintain memory safety
                    mstore(0x40, nextFreePtr)
                    // return the values
                    leave
                }
                // word array
                if lt(schemaByte, MAX_LIKE_111001XX) {
                    // get lengthWidth of value to load by masking schemaByte and adding 1
                    let lengthWidth := add(1, and(schemaByte, LENGTH_MASK))
                    // calculate right shift to apply to loaded length
                    let rightShift := sub(256, shl(lengthWidth, 3))
                    // load length from calldata
                    pos := add(1, pos)
                    let length := shr(rightShift, calldataload(pos))
                    let dest := freePtr
                    // store length at freePtr
                    mstore(dest, length)
                    // calculate actual bytes length
                    let bytesLength := shl(5, length)
                    dest := add(freePtr, 0x20)
                    pos := add(pos, lengthWidth)
                    // copy the data from calldata to memory
                    calldatacopy(dest, pos, bytesLength)
                    // calculate abi-encoded relative offset to store at memIdx
                    val := sub(freePtr, absStart)
                    // calculate next position to read from
                    nextPos := add(pos, mul(length, 0x20))
                    nextFreePtr := add(dest, bytesLength)
                    // increment and update freePtr to maintain memory safety
                    mstore(0x40, nextFreePtr)
                    // return the values
                    leave
                }
                // homogenous NByte-array
                if lt(schemaByte, MAX_LIKE_111010XX) {
                    // get lengthWidth of value to load by masking schemaByte and adding 1
                    let lengthWidth := add(1, and(schemaByte, LENGTH_MASK))
                    // calculate right shift to apply to loaded length
                    let rightShift := sub(256, shl(lengthWidth, 3))
                    // load element width from next byte in loaded word
                    // mask
                    let bytesWidth := add(1, and(byte(1, indexWord), VALUE_WIDTH_MASK))
                    let leftShift := byte(2, indexWord)
                    // load length from calldata
                    pos := add(3, pos)
                    let length := shr(rightShift, calldataload(pos))
                    pos := add(lengthWidth, pos)
                    val, nextPos, nextFreePtr := copyNByteArray(pos, bytesWidth, leftShift, length, absStart, freePtr)
                    leave
                }
                // XRLP-encoded array: heterogenous NByte, Struct[]
                if lt(schemaByte, MAX_LIKE_111011XX) { leave }
                // XRLP-encoded object: Struct
                if lt(schemaByte, MAX_LIKE_111100XX) { leave }
                // Pointer
            }

            let start := 1
            let pragmaByte := byte(0, calldataload(0))
            for {} true {} { if eq(pragmaByte, 1) {} }
        }
    }
}
