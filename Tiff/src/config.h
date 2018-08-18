//===============================================================================
// config.h
//===============================================================================
#ifndef __CONFIG_H__
#define __CONFIG_H__

// Sizes of internal memories in 32-bit cells
#define RAMsize   0x400                         /* must be an exact power of 2 */
#define ROMsize   0x800                         /* must be an exact power of 2 */
#define AXIsize   0x4000             /* SPI flash, must be a multiple of 0x400 */

// Copy internal ROM writes to SPI flash, Defined if SPI gets a copy of the ROM image.
#define BootFromSPI

// Instruments the VM to allow Undo and Redo
 #define TRACEABLE
#define TraceDepth 12               /* Log2 of the trace buffer size, 13*2^N bytes */

// number of rows in the CPU register dump, minimum 9, maximum 12
#define DumpRows         10

// Comment out if your terminal supports color escape codes. See colors.h for colors.
// Note that if you want to pipe a bunch of stdout to a file, you want monochrome.
// #define MONOCHROME

#define OKstyle  2     /* Style of OK prompt: 0=classic, 1=openboot, 2=depth */
// #define VERBOSE     /* for debugging the quit loop, etc. */

// A word is reserved for a forward jump to cold boot, kernel starts at 000004.
// These are byte addresses.
#define CodePointerOrigin  4                  /* Kernel definitions start here */
#define HeadPointerMin    ((ROMsize+RAMsize)*4)     /* Lowest SPI code address */
#define HeadPointerOrigin  0x8000       /* Headers are in AXI space above code */

//===============================================================================
// Sanity checks

#if (RAMsize & (RAMsize-1))
#error RAMsize must be a power of 2
#endif

#if (ROMsize & (ROMsize-1))
#error ROMsize must be a power of 2
#endif

#if (ROMsize & (RAMsize-1))
#error ROMsize must be a multiple of RAMsize
#endif

#if (AXIsize & 0x3FF) // To match SPI flash sectors
#error AXIsize must be a multiple of 1024 (0x400)
#endif

#endif
