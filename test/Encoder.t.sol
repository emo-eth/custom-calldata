// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {Encoder} from "src/Encoder.sol";

contract EncoderTest is Test {
    function testEncodeType1() public {
        bytes32 x = 0x0000;
        bytes memory encoded = Encoder.encodeType1(x);
        assertEq(encoded.length, 2);
        assertEq(encoded[0], 0x00);
        assertEq(encoded[1], 0x00);
        x = bytes32(uint256(1));
        encoded = Encoder.encodeType1(x);
        assertEq(encoded.length, 2);
        assertEq(encoded[0], 0x00);
        assertEq(encoded[1], bytes1(0x01));
        x = bytes32(uint256(255));
        encoded = Encoder.encodeType1(x);
        assertEq(encoded.length, 2);
        assertEq(encoded[0], 0x00);
        assertEq(encoded[1], bytes1(0xff));
        x = bytes32(uint256(256));
        encoded = Encoder.encodeType1(x);
        assertEq(encoded.length, 3);
        assertEq(encoded[0], bytes1(0x01));
        assertEq(encoded[1], bytes1(0x01));
        assertEq(encoded[2], 0x00);

        x = bytes32(uint256(65535));
        encoded = Encoder.encodeType1(x);
        assertEq(encoded.length, 3);
        assertEq(encoded[0], bytes1(0x01));
        assertEq(encoded[1], bytes1(0xff));
        assertEq(encoded[2], bytes1(0xff));

        x = bytes32(uint256(65536));
        encoded = Encoder.encodeType1(x);

        assertEq(encoded.length, 4);
        assertEq(encoded[0], bytes1(0x02));
        assertEq(encoded[1], bytes1(0x01));
        assertEq(encoded[2], 0x00);
        assertEq(encoded[3], 0x00);

        uint256 y;
        assembly {
            y := not(0)
        }
        x = bytes32(y);
        encoded = Encoder.encodeType1(x);
        assertEq(encoded.length, 33);
        assertEq(encoded[0], bytes1(0x1f));
        assertEq(encoded[1], bytes1(0xff));
        assertEq(encoded[32], bytes1(0xff));
    }

    function testEncodeType2() public {
        bytes32 x = bytes32(bytes1(0x00));
        bytes memory encoded = Encoder.encodeType2(x);
        assertEq(encoded.length, 2);
        assertEq(encoded[0], 0x00);
        assertEq(encoded[1], 0x00);

        x = bytes32(bytes1(0x01));
        encoded = Encoder.encodeType2(x);
        assertEq(encoded.length, 3);
        assertEq(encoded[0], bytes1(uint8(0x00 | Encoder.EXPAND_FLAG)));
        assertEq(encoded[1], bytes1(uint8(248)));
        assertEq(encoded[2], bytes1(0x01));

        x = bytes32(bytes2(0x00ff));
        encoded = Encoder.encodeType2(x);
        assertEq(encoded.length, 3);
        assertEq(encoded[0], bytes1(uint8(0x00 | Encoder.EXPAND_FLAG)));
        assertEq(encoded[1], bytes1(uint8(240)));
        assertEq(encoded[2], bytes1(0xff));
        x = bytes32(uint256(1));
        encoded = Encoder.encodeType2(x);
        assertEq(encoded.length, 2);
        assertEq(encoded[0], 0x00);
        assertEq(encoded[1], bytes1(0x01));
        x = bytes32(uint256(1 << 255) - 1);
        encoded = Encoder.encodeType2(x);
        assertEq(encoded.length, 33);
        assertEq(encoded[0], bytes1(uint8(0x1f)));
        assertEq(encoded[1], bytes1(0x7f));
        assertEq(encoded[32], bytes1(0xff));

        x = bytes32(bytes4(0x000001c0));
        encoded = Encoder.encodeType2(x);
        assertEq(encoded.length, 3);
        assertEq(encoded[0], bytes1(uint8(0x00 | Encoder.EXPAND_FLAG)));
        assertEq(encoded[1], bytes1(uint8(230)));
        assertEq(encoded[2], bytes1(0x07));
    }

    function testEncodeType2SpanningBits() public {
        uint256 x;
        for (uint256 i = 4; i < 31; i++) {
            uint256 bits = i * 8;
            uint256 shift = bits + 7;
            x = 3 << shift;
            bytes memory encoded = Encoder.encodeType2(bytes32(x));
            assertEq(encoded.length, 3);
            assertEq(encoded[0], bytes1(uint8(0x00 | Encoder.EXPAND_FLAG)));
            assertEq(encoded[1], bytes1(uint8(shift)));
            assertEq(encoded[2], bytes1(0x03));
        }
    }

    function testEncodePackingBits() public {
        uint256 x;
        for (uint256 i = 0; i < Encoder.EXPANSION_BIT_CUTOFF; i++) {
            x = 1 << i;
            bytes memory encoded = Encoder.encodeType2(bytes32(x));
            assertEq(encoded.length, 2 + (i / 8), "bad length");
            assertEq(encoded[0], bytes1(uint8(i / 8)), "bad meta");
            assertEq(encoded[1], bytes1(uint8(1 << (i % 8))), "bad value");
        }
        for (uint256 i = Encoder.EXPANSION_BIT_CUTOFF; i < 256; i++) {
            x = 1 << i;
            bytes memory encoded = Encoder.encodeType2(bytes32(x));
            assertEq(encoded.length, 3, "bad length");
            assertEq(encoded[0], bytes1(uint8(0x00 | Encoder.EXPAND_FLAG)), "bad meta");
            assertEq(encoded[1], bytes1(uint8(i)), "bad expand");
            assertEq(encoded[2], bytes1(0x01), "bad val");
        }
    }

    function testMsb() public {
        assertEq(Encoder.msb(0), 0);
        for (uint256 i; i < 256; i++) {
            assertEq(Encoder.msb(1 << i), i);
        }
    }

    function testLsb() public {
        uint256 mask = 1 << 255;
        assertEq(Encoder.lsb(0), 0);
        for (uint256 i; i < 256; i++) {
            assertEq(Encoder.lsb(mask | (1 << i)), i);
        }
    }
}
