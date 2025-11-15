On a Zynq-7020 device:

JTAG IR is 10-bit long.

| JTAG IR | ARM DAP IR | ARM DAP Mode | PL TAP IR   | PL TAP Mode | Readback Value |
|---------|------------|--------------|-------------|-------------|----------------|
| `0x3FF` | `0b1111`   | BYPASS       | `0b11_1111` | BYPASS      | Input value, shifted left by two bits |
| `0x3BF` | `0b1110`   | ARM IDCODE   | `0b11_1111` | BYPASS      | ARM IDCODE, shifted left by one bit |
| `0x3C9` | `0b1111`   | BYPASS       | `0b00_1001` | IDCODE      | PL IDCODE, exact match |
| `0x3E3` | `0b1111`   | BYPASS       | `0b10_0011` | USER4       | Implementation-defined, read data exact match, write data shifted left by one bit |

# ARM IDCODE

- Readback IDCODE: `0x974008ee`
- Expected IDCODE from ARM DAP: `0x4BA00477`
- Expected value obtained by shifting readback value one bit to the right

# PL IDCODE

- Readback IDCODE: `0x23727093`
- Expected IDCODE from PL TAP: `0x23727093`
- Exact match

# PL USER4

- Readback exact match
- Add one-bit to the DR length to account for single-bit BYPASS DR in ARM DAP
