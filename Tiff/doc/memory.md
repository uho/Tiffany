# Memory Model

The memory model uses 32-bit byte addresses in little endian format. Physical memory consists of:

- Internal ROM for code
- Internal dual-port RAM for data
- External AXI space

Code ROM is synchronous-read ROM. Data RAM is dual-port synchronous RAM. In an ASIC, masked ROM is 1/10th to 1/20th the die area of dual-port RAM (per bit), so a decent amount of area is available for code. In an FPGA, you typically have 18Kb blocks of DPRAM, so 512-word chunks. The RAM needs byte lane enables.

AXI is a streaming-style system interface where data is best transferred in bursts due to long latency times. It's the standard industry interface. Rather than abstracting it away, the ISA gives direct control to the programmer. Several opcodes are multi-cycle instructions that stream RAM data to and from the AXI bus.

## Word Size

Cells should have enough bits to address a SPI flash using byte addressing. The biggest SPI NOR flash Digikey has in stock as of mid 2018 is 128M bytes, so a 27-bit address range. 32-bit memory words are then a no-brainer. That's compatible with commercial Forth systems, which are also 32-bit. Byte order is little-endian.

## Address Ranges

In Tiff, #defines in config.h specify the sizes (in 32-bit words) of RAM and ROM as `RAMsize` and `ROMsize` respectively.

| Type | Range                        | AXI Read   | AXI Write  |
| -----|:----------------------------:|-----------:|-----------:|
| ROM  | 0 to ROMsize-1               | -          | -          |
| RAM  | ROMsize to ROMsize+RAMsize-1 | Burst In   | Burst Out  |
| AXI  | Other                        | Code fetch | -          |  

AXI space starts at address 0. Tiff treats this as SPI flash. It's up to the implementation to write-protect the bottom of SPI flash so as to not be able to wipe out header space. The AXI address range of \[0 to ROMsize+RAMsize-1\] is a section of SPI flash that's unreachable by the PC, so you can't run code from it or read it with the normal fetch opcodes. However, it can be streamed into RAM. Two opcodes are reserved for transferring bursts of RAM data to and from AXI space.

An application could keep data in the \[0 to ROMsize+RAMsize-1\] range, or an FPGA version could load code RAM with a ROM image from SPI flash at power-up.

Tiff simulates a blank flash in AXI space and applies the rule of never writing a '0' bit twice to the same bit without erasing it first. Such activity may over-charge the floating gate (if the architecture doesn't prevent it), leading to reliability problems. Tiff writes ROM data to both AXI space and internal ROM when simulating the "Load code RAM from SPI flash" boot method.

## Streaming Operations

Read channel of AXI:

- AXI\[PC\] to the IR, one word, for extended code space fetch (not an opcode)
- AXI\[A\] to RAM for streaming in a working buffer

Write channel of AXI:

- Code RAM to AXI\[A\] for streaming out a working buffer

Getting single words from the AXI read channel could take tens of cycles. However, since almost all time is spent in internal code space it doesn't matter. A little prefetch buffering would help things along. 

The AXI4 protocol allows for a burst size between 1 and 256 words. Bursts use 32-bit words.