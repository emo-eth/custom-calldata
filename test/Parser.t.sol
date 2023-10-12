// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Parser} from "../src/Parser.sol";

contract ParserTest is Test {
    Parser public parser;

    function setUp() public {
        parser = new Parser();
    }

    function testReadSingleType1(uint256 valToEncode) public {
        uint256 numBytes = getNumBytes(valToEncode);
        uint256 meta = (numBytes > 0) ? numBytes - 1 : 0;
        uint256 bytesLen = (numBytes > 0) ? numBytes + 1 : 2;
        uint256 toEncode = valToEncode << ((32 - numBytes) * 8);
        bytes memory context;
        emit log_named_uint("numBytes", numBytes);
        emit log_named_uint("meta", meta);
        emit log_named_uint("bytesLen", bytesLen);
        emit log_named_uint("toEncode", toEncode);
        assembly {
            context := mload(0x40)
            mstore(context, bytesLen)
            mstore8(add(context, 1), meta)
            mstore(add(context, 33), toEncode)
        }

        bytes32 readValue = parser.readSingle(false, context);
        assertEq(readValue, bytes32(valToEncode));
    }

    function testReadSingleType1d() public {
        uint256 valToEncode = 0;
        uint256 numBytes = getNumBytes(valToEncode);
        uint256 meta = (numBytes > 0) ? numBytes - 1 : 0;
        uint256 bytesLen = (numBytes > 0) ? numBytes + 1 : 2;
        uint256 toEncode = valToEncode << ((32 - numBytes) * 8);
        bytes memory context;
        emit log_named_uint("numBytes", numBytes);
        emit log_named_uint("meta", meta);
        emit log_named_uint("bytesLen", bytesLen);
        emit log_named_uint("toEncode", toEncode);
        assembly {
            context := mload(0x40)
            mstore(context, bytesLen)
            mstore8(add(context, 1), meta)
            mstore(add(context, 33), toEncode)
        }

        bytes32 readValue = parser.readSingle(false, context);
        assertEq(readValue, bytes32(valToEncode));
    }

    function getNumBytes(uint256 x) internal pure returns (uint256) {
        uint256 numBytes = 0;
        while (x > 0) {
            x >>= 8;
            numBytes++;
        }
        return numBytes;
    }

    function getCompressableBytes(uint256 x) internal pure returns (uint256) {
        uint256 numBytes = lsb(x) / 8;
        if (numBytes == 32) {
            return 0;
        }
        return numBytes;
    }

    function msb(uint256 x) internal pure returns (uint256) {
        // get msb from the right
        uint256 _msb = 0;
        while (x > 0) {
            x >>= 1;
            _msb++;
        }
        return _msb;
    }

    function lsb(uint256 x) internal pure returns (uint256) {
        // get lsb from the right
        uint256 _lsb = 0;
        while (x > 0) {
            if (x & 1 == 1) {
                return _lsb;
            }
            x >>= 1;
            _lsb++;
        }
        return _lsb;
    }
}
