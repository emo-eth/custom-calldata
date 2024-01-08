// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

uint256 constant EXPANSION_BIT_CUTOFF = 32; // 4 bytes
uint256 constant BITS_TO_BYTES_SHIFT = 3;
uint256 constant FREE_PTR = 0x40;
uint256 constant ONE_WORD = 0x20;
uint256 constant TWO_WORDS = 0x40;
uint256 constant ONE_BYTE_BITS = 8;
// uint256 constant TYPE_ZERO = 0;
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
