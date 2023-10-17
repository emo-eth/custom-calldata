// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Parser} from "../Parser.sol";
import {Encoder} from "../Encoder.sol";

struct MyStruct {
    uint256 a;
    uint32 b;
    bytes4 c;
}

library MyStructLib {
    error InvalidPointer();

    function decode(uint256 pos) internal pure returns (MyStruct memory decoded, uint256 newPos) {
        bytes32 relativePointer;
        bool isPointer;
        (relativePointer, newPos, isPointer) = Parser.readSingle(pos);
        if (!isPointer) {
            revert InvalidPointer();
        }
        uint256 tempPtr = uint256(relativePointer) + pos;
        bytes32 temp;
        (temp, tempPtr, isPointer) = Parser.readSingle(tempPtr);
        decoded.a = uint256(temp);
        (temp, tempPtr, isPointer) = Parser.readSingle(tempPtr);
        decoded.b = uint32(uint256(temp));
        (temp, tempPtr, isPointer) = Parser.readSingle(tempPtr);
        decoded.c = bytes4(temp);
        return (decoded, newPos);
    }

    function decodePacked(uint256 pos) internal pure returns (MyStruct memory decoded, uint256 newPos) {
        bytes32 temp;
        (temp, newPos,) = Parser.readSingle(pos);
        decoded.a = uint256(temp);
        (temp, newPos,) = Parser.readSingle(newPos);
        decoded.b = uint32(uint256(temp));
        (temp, newPos,) = Parser.readSingle(newPos);
        decoded.c = bytes4(temp);
        return (decoded, newPos);
    }

    /**
     * @notice Encode the struct into a bytes array without encoding a pointer
     * @param input The struct to encode
     */
    function encode(MyStruct memory input) internal pure returns (bytes memory encoded) {
        encoded = Encoder.encodeType2(bytes32(input.a));
        encoded = bytes.concat(encoded, Encoder.encodeType2(bytes32(uint256(input.b))));
        encoded = bytes.concat(encoded, Encoder.encodeType2(bytes32(input.c)));
        return encoded;
    }
}
