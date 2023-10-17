# Custom Calldata

This is an experimental library for creating custom calldata encoding and parsing for structs in Solidity.

It is meant to be used with codegen tools to automatically create the encoding and decoding functions for structs.

See [MyStruct](src/lib/MyStruct.sol) for a toy example.

# Overview

## Type1

`Type1` encoding uses a "meta" byte to encode the number of bytes "from the left" (minus 1 if not 0) that a value occupies.

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

- Marginally cheaper to decode than `Type2` (~40 gas per word)

### Cons

- Inefficient for "left-skewed" values such as `bytesN`-types or very large numbers
- Inefficient for values that occupy 28 bytes or more
- Can't compress "middle" bytes

### Type2

`Type2` encoding uses a "meta" byte to encode the number of bytes "from the right" (minus 1 if not 0) that a value occupies, and a flag indicating whether the following byte encodes the power of 2 that the succeeding bytes should be multiplied by. If the flag is not present, the "expansion bits" are not encoded at all.
By default, `Type2` encoding will not attempt to "compress" fewer than 32 bits, since 1 non-zero byte of calldata is as expensive as 4 zero-bytes of calldata.

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

- Only right-packs values when it's economical to do so
- Can encode values that are "left-skewed" such as `bytesN`-types or very large numbers

### Cons

- Marginally more expensive to decode than `Type1` (~40 gas per word)
- Still inefficient for values that occupy 28 bytes or more
- Can't compress "middle" bytes

## Pointers

The "meta" byte can optionaly encode a "pointer" flag (`1 << 6`) to indicate to decoders that the value is a pointer to a relative offset, similar to current ABI-encoding behavior.

## Caveats

- The encoding schemes are inefficient for values that occupy 28 bytes or more, since the non-zero "meta" byte is as expensive as 4 zero-bytes.
- Constant-time access of values in calldata is not possible, since the offset of each value is dependent on the length of each previous value
  - This could maybe be compensated for, eg, array indexing by storing word-aligned arrays of items when convenient
- Decoding values oftentimes costs more gas than is saved by the compact encoding
  - This is a decent tradeoff for, eg, L2s, where calldata gas costs are several orders of magnitude more expensive than compute
- The encoding schemes are obviously not compatible with traditional ABI encoding
