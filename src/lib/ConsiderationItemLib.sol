// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ConsiderationItem} from "seaport-types/lib/ConsiderationStructs.sol";
import {ItemType} from "seaport-types/lib/ConsiderationEnums.sol";
import {Parser} from "../Parser.sol";
import {Encoder} from "../Encoder.sol";

library ConsiderationItemLib {
    error InvalidPointer();

    function decodeFromPointer(uint256 pos) internal pure returns (ConsiderationItem memory decoded, uint256 newPos) {
        bytes32 relativePointer;
        bool isPointer;
        (relativePointer, newPos, isPointer) = Parser.readSingle(pos);
        if (!isPointer) {
            revert InvalidPointer();
        }
        uint256 tempPtr = uint256(relativePointer) + pos;
        bytes32 temp;
        (temp, tempPtr, isPointer) = Parser.readSingle(tempPtr);
        decoded.itemType = ItemType(uint8(uint256(temp)));
        (temp, tempPtr, isPointer) = Parser.readSingle(tempPtr);
        decoded.token = address(uint160(uint256(temp)));
        (temp, tempPtr, isPointer) = Parser.readSingle(tempPtr);
        decoded.identifierOrCriteria = uint256(temp);
        (temp, tempPtr, isPointer) = Parser.readSingle(tempPtr);
        decoded.startAmount = uint256(temp);
        (temp, tempPtr, isPointer) = Parser.readSingle(tempPtr);
        decoded.endAmount = uint256(temp);
        (temp, tempPtr, isPointer) = Parser.readSingle(tempPtr);
        decoded.recipient = payable(address(uint160(uint256(temp))));

        return (decoded, newPos);
    }

    function decode(uint256 pos) internal pure returns (ConsiderationItem memory decoded, uint256 newPos) {
        bytes32 temp;
        (temp, newPos,) = Parser.readSingle(pos);
        decoded.itemType = ItemType(uint8(uint256(temp)));
        (temp, newPos,) = Parser.readSingle(newPos);
        decoded.token = address(uint160(uint256(temp)));
        (temp, newPos,) = Parser.readSingle(newPos);
        decoded.identifierOrCriteria = uint256(temp);
        (temp, newPos,) = Parser.readSingle(newPos);
        decoded.startAmount = uint256(temp);
        (temp, newPos,) = Parser.readSingle(newPos);
        decoded.endAmount = uint256(temp);
        (temp, newPos,) = Parser.readSingle(newPos);
        decoded.recipient = payable(address(uint160(uint256(temp))));

        return (decoded, newPos);
    }

    function encode(ConsiderationItem memory input) internal pure returns (bytes memory encoded) {
        encoded = Encoder.encodeType2(bytes32(uint256(input.itemType)));
        encoded = bytes.concat(encoded, Encoder.encodeType2(bytes32(uint256(uint160(input.token)))));
        encoded = bytes.concat(encoded, Encoder.encodeType2(bytes32(input.identifierOrCriteria)));
        encoded = bytes.concat(encoded, Encoder.encodeType2(bytes32(input.startAmount)));
        encoded = bytes.concat(encoded, Encoder.encodeType2(bytes32(input.endAmount)));
        encoded = bytes.concat(encoded, Encoder.encodeType2(bytes32(uint256(uint160(address(input.recipient))))));

        return encoded;
    }
}
