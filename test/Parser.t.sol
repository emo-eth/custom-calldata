// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Parser} from "../src/Parser.sol";
import {Encoder} from "../src/Encoder.sol";

contract ParserTest is Test {
    function testReadSingleType1(bytes32 valToEncode) public {
        bytes memory context = Encoder.encodeType1(valToEncode);
        (bytes32 readValue,,) = this.readSingleType1(context);
        assertEq(readValue, bytes32(valToEncode));
    }

    function testReadSingleType2(bytes32 valToEncode) public {
        bytes memory context = Encoder.encodeType2(valToEncode);
        (bytes32 readValue,,) = this.readSingleType2(context);
        assertEq(readValue, bytes32(valToEncode));
    }

    function testReadSingleOmni(bytes32 valToEncode) public {
        bytes memory context = Encoder.encodeType1(valToEncode);
        (bytes32 readValue,,) = this.readSingle(context);
        assertEq(readValue, bytes32(valToEncode));
        context = Encoder.encodeType2(valToEncode);
        (readValue,,) = this.readSingle(context);
        assertEq(readValue, bytes32(valToEncode));
    }

    function readSingle(bytes calldata context) public pure returns (bytes32, uint256, bool) {
        return Parser.readSingle(context);
    }

    function readSingleType1(bytes calldata context) public pure returns (bytes32, uint256, bool) {
        return Parser.readSingleType1(context);
    }

    function readSingleType2(bytes calldata context) public pure returns (bytes32, uint256, bool) {
        return Parser.readSingleType2(context);
    }

    function testCompareGas(bytes4 valToEncode) public {
        bytes memory context = Encoder.encodeType1(bytes32(valToEncode));
        this.compare(context);
    }

    function testOmniCompareGas(bytes4 valToEncode) public {
        bytes memory context1 = Encoder.encodeType1(bytes32(valToEncode));

        bytes memory context2 = Encoder.encodeType2(bytes32(valToEncode));
        this.compare2(context1, context2);
    }

    function compare(bytes calldata context) public returns (bytes32) {
        unchecked {
            uint256 gas = gasleft();
            (bytes32 x,,) = Parser.readSingleType1(context);
            uint256 result = gas - gasleft();
            emit log_named_uint("type1 gas", result);
            gas = gasleft();
            (bytes32 y,,) = Parser.readSingleType2(context);
            result = gas - gasleft();
            emit log_named_uint("type2 gas", result);
            return x | y;
        }
    }

    function compare2(bytes calldata context1, bytes calldata context2) public returns (bytes32) {
        unchecked {
            uint256 gas = gasleft();
            (bytes32 x,,) = Parser.readSingle(context1);
            uint256 result = gas - gasleft();
            emit log_named_uint("type1 gas", result);
            gas = gasleft();
            (bytes32 y,,) = Parser.readSingle(context2);
            result = gas - gasleft();
            emit log_named_uint("type2 gas", result);
            return x | y;
        }
    }
}
