# Custom Calldata

This is an experimental library for creating custom calldata encoding and parsing for structs in Solidity.

It is meant to be used with codegen tools to automatically create the encoding and decoding functions for structs.

See [MyStruct](src/lib/MyStruct.sol) for a toy example.

# Overview

## "Meta" byte

Encoded values are prefixed with a "meta" (name needs workshopping) byte that encodes the number of bytes "from the left" (minus 1, if not 0) that a value occupies in the lower 5 bits.

The top 3 bits of a "meta" byte encode different instructions for parsing, enumerated in the following table (WIP):

| Value      | Name                      | Description                                                                                                                                                                                                                           |
| ---------- | ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0x000xxxxx | Standard Type1            | Indicates the encoded value `X` occupies the following N+1 bytes                                                                                                                                                                      |
| 0x001xxxxx | Standard Type2            | Indicates the next byte encodes a power of two. The following N+1 bytes contain the encoded value `log_2(X)`.                                                                                                                         |
| 0x010xxxxx | Pointer (metadata)        | Indicates the encoded value `X` occupies the following N+1 bytes. The value itself should be treated as a relative offset pointing to the actual encoded value. Custom encoders and decoders can decide how and when to use pointers. |
| 0x011xxxxx | Type3                     | Indicates the next byte encodes a power of two. The following N+1 bytes encode `not(log_2(X))`.                                                                                                                                       |
| 0x100xxxxx | Literal Bytes Array       | Indicates that, for `bytes` array `A`, the encoded value `A.length` occupies the following N+1 bytes. The following `A.length` bytes are the literal contents of the `bytes` array `A`.                                               |
| 0x101xxxxx | Literal Word Array        | Indicates that, for a `value-type` array `A` (eg: `bytes32[]`), the encoded value `A.length` occupies the following N+1 bytes. The following `A.length * 32` bytes are the literal contents of the word-encoded array `A`.            |
| 0x110xxxxx | Fixed member-length Array |                                                                                                                                                                                                                                       |
| 0x111xxxxx | Unused                    |                                                                                                                                                                                                                                       |

## Type1

`Type1` encoding uses a single "meta" byte to encode the number of bytes "from the left" (minus 1 if not 0) that a value occupies.

Examples:

```
Value: 0x0000000000000000000000000000000000000000000000000000000000000000  // 32 zero-bytes
Type1: 0x0000                                                              // 2 zero-bytes
Value: 0x0000000000000000000000000000000000000000000000000000000000000001  // 31 zero-bytes, 1 non-zero byte
Type1: 0x0001                                                              // 1 zero-byte,   1 non-zero byte
Value: 0x0000000000000000000000000000000000000000000000000000000000000100  // 31 zero-bytes, 1 non-zero byte
Type1: 0x010100                                                            // 1 zero-byte,   2 non-zero bytes
Value: 0x0100000000000000000000000000000000000000000000000000000000000000 // 31 zero-bytes, 1 non-zero byte
Type1: 0x1f0100000000000000000000000000000000000000000000000000000000000000 // 31 zero-bytes, 2 non-zero bytes
```

### Pros

-   Marginally cheaper to decode than `Type2` (~40 gas per word)

### Cons

-   Inefficient for "left-skewed" values such as `bytesN`-types or very large numbers
-   Inefficient for values that occupy 28 bytes or more
-   Can't compress "middle" bytes

### Type2

`Type2` encoding uses a "meta" byte to encode the number of bytes "from the right" (minus 1 if not 0) that a value occupies, and an additional byte containing the power of 2 that the succeeding N+1 bytes should be multiplied by.
`Type2` encoding will not attempt to "compress" fewer than 32 bits, since 1 non-zero byte of calldata is as expensive as 4 zero-bytes of calldata.

```
Value: 0x0000000000000000000000000000000000000000000000000000000000000000  // 32 zero-bytes
Type2: 0x0000                                                              // 2 zero-bytes
Value: 0x0000000000000000000000000000000000000000000000000000000000000001  // 31 zero-bytes, 1 non-zero byte
Type2: 0x0001                                                              // 1 zero-byte,   1 non-zero byte
Value: 0x0000000000000000000000000000000000000000000000000000000000000100  // 31 zero-bytes, 1 non-zero byte
Type2: 0x010100                                                            // 1 zero-byte,   1 non-zero byte
Value: 0x0100000000000000000000000000000000000000000000000000000000000000  // 31 zero-bytes, 1 non-zero byte
Type2: 0x20f801                                                            // 0 zero-bytes,  3 non-zero bytes
Value: 0x0000000000000000000000000000000000000000000000000000001000000000  // 31 zero-bytes, 1 non-zero byte
Type2: 0x202401                                                            // 0 zero-bytes,  3 non-zero bytes
Value: 0x000000000000000000000000000000000000000000000000000001c000000000  // 30 zero-bytes, 2 non-zero bytes
Type2: 0x202607                                                            // 0 zero-bytes,  3 non-zero bytes
Value: 0x0000000000000000000000000000000000000000000000000001c11000000000  // 29 zero-bytes, 3 non-zero bytes
Type2: 0x21241c11                                                          // 0 zero-bytes,  4 non-zero bytes
```

### Pros

-   Only right-packs values when it's economical to do so
-   Can encode values that are "left-skewed" such as `bytesN`-types or very large numbers

### Cons

-   Marginally more expensive to decode than `Type1` (~40 gas per word)
-   Still inefficient for values that occupy 28 bytes or more
-   Can't compress "middle" bytes

### Type3

`Type3` encoding uses a "meta" byte to encode the number of bytes "from the right" (minus 1 if not 0) that an encoded value occupies, and an additional byte containing the power of 2 that the succeeding N+1 bytes should be multiplied by, once bitwise-negated.

Type3 is useful for encoding negative integers, or values with many upper bits set.

## Caveats

-   The encoding schemes are inefficient for values that occupy 28 bytes or more, since the non-zero "meta" byte is as expensive as 4 zero-bytes.
-   Constant-time access of values in calldata is not possible, since the offset of each value is dependent on the length of each previous value
    -   This could maybe be compensated for, eg, array indexing by storing word-aligned arrays of items when convenient
-   Decoding values oftentimes costs more gas than is saved by the compact encoding
    -   This is a decent tradeoff for, eg, L2s, where calldata gas costs are several orders of magnitude more expensive than compute
-   Only reads from `calldata` (for now)
-   The encoding schemes are obviously not compatible with traditional ABI encoding
