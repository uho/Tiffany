# Header space

The most important thing about header space is that it lives in flash memory. The basic rule about flash programming is that you can only change a '1' to a '0'. Erased flash starts out at '1'. You may not program a '0' to the same bit twice. A good chip design might mitigate the possible damage caused by this, but you don't know about the parts you're dealing with. Writing a '0' to the same bit twice without erasing in between could over-charge the floating gate causing problems with incomplete erasure and reading of adjacent bits. So, Tiff throws an error if you try to program a '0' into a bit that's already at '0'.

An application can run without header space. It just won't have an interpreter. This is not a problem in embedded systems. SPI flash could be used in development and removed in the final system. Think of physically beheading a system by de-soldering the flash chip.

## To Hash or Not to Hash

Some Forths use a hashed dictionary, where the name to be searched uses a hash to resolve the dictionary thread to search. Is this necessary? Consider the case of headers being kept in SPI flash, clocked at 25 MHz by an MCU's SPI port. Random 32-bit reads spend about 4 usec setting the address and reading the 32-bit link followed by a 32-bit packed name and name length. A typical Forth app tends to be in the 1000-word range. With one dictionary thread, that would take 4 ms to search. Using the scheme of following the list forward to find the end, since it doesn't have an end pointer until it's programmed once into the flash, add another 3 ms. So, 7 ms for a search.

A Forth app with 10,000 words would take 70 seconds to load at that rate, but since the dictionary is built up linearly from nothing it would be more like 35 seconds. Reloading the app would be rarely done. Half a minute for something rarely done isn't bad. More reasonable hardware would use quad SPI at 50 MHz, or 10x the speed.

Tiff, being a PC app, should be fast even while reading the flash image by stepping a simulated stack computer. Benchmarking on a laptop i7 found 150ns per simulated SPI flash fetch. There are three of these per header, so with 1000 words a search should cost 150 usec. Multiplied by 10k searches is 1.5 sec. A more realistic estimate using a dictionary built from scratch gives a load time of less than a second.

There's no need to hash the dictionary. In the interest of minimizing the size of target code, hashing is not used.

## Header Data Structure

Header space is a section of code space. It uses links and execution tokens wide enough to hit all of code space, including internal ROM and add-on definitions in flash. 24-bit cell addressing allows this range to cover 64M bytes.

Headers can be skinny or fat, depending on how much built-in cross-referencing is done. To handle this, format bits are included in the header. The backward link and the name should be adjacent in memory to allow for faster fetch from SPI flash. Forward links are necessary in a flash-based dictionary because sometimes forward traversal is needed. A newly created minimal header also contains dual-xts, which are loaded upon header creation or resolved later.

Note that unresolved fields in a packed record are allowed. The bits outside the field of interest are written with '1' when nearby fields are resolved. The header is:

| Cell | \[31:24\]                        | \[23:0\]                           |
| ---- |:---------------------------------| ----------------------------------:|
| -3   | Source File ID                   | List of words that this references |
| -2   | Source Line, Low byte            | List of words that reference this  |
| -1   | Source Line, High byte           | Forward Link                       |
| 0    | -1 (reserved)                    | xtc, Execution token for compile   |
| 1    | W (upper byte)                   | W (lower 3 bytes)                  |
| 2    | # of instructions in definition  | xte, Execution token for execute   |
| 3    | # of instructions high byte      | Backward Link                      |
| 4    | Name Length                      | Name Text                          |

The cross reference structure contains lists of cross reference structures. Since the links can only be written once, the list must be traversed in order to add to it. The list is kept short by doubling the element size with each link taken. The HEAD cells are addresses of the corresponding header structure, from which a name and source code location may be obtained.

The name length byte includes smudge, immediate, and call-only bits that default to '1' and are set to '0' later on.

## Wordlists

A classical wordlist data structure contains a pointer (or an array of pointers if hashing is used) in RAM that gets updated each time a header is added to the dictionary. That’s a problem for a flash-based system. You want to add to the end of the dictionary using a read-only wordlist. The way around this is with a doubly linked list.

Although the wordlist ID points to the start of the read-only structure, its first cell starts out as -1. The word `GILD` ( wid -- ) resolves it by traversing forward to the end of the list and replacing the -1 with that address. A forward traversal is terminated by hitting blank flash (-1). If hashed wordlists are used, the number of hash threads is the size of the array, in cells, containing -1 at the wordlist structure.

## Source File ID

There is a forward linked list for filenames. If a filename exists in the list, its position in the list is its ID number. If it must be appended, the filename is added to the list and the previously blank forward link (located by traversal) is populated.

When Tiff's "include" opens a file, it adds the filename to this list by compiling a -1 (blank link) and the filename to head space, which uses HP as its pointer. Then it resolves the previous element's forward link.

