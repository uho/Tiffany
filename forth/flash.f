\ SPI flash access through `5 user`.

\ In Tiff, a SPI flash chip is simulated in tiffUser.c.
\ Real hardware will have an actual SPI flash chip that uses the same commands.
\ This code must run in internal ROM:

: SPIxfer     \ command -- result
   5 user                               \ Flash, a-ah, king of the impossible
;

: SPIaddr  \ addr command final --      \ initiate a command with 24-bit address
   >r
   SPIxfer drop  hld dup >r ! r>        \ use a cell for extracting bytes
   count >r  count >r  c@               \ low med high
   SPIxfer drop                         \ assuming a little-endian model
   r> SPIxfer drop
   r> r> + SPIxfer drop
;

: SPIaddress  \ addr command final --   \ initiate a command with 24-bit address
   hld dup @ >r  swap >r >r             \ R: hld final 'hld
   SPIxfer drop                         \ send command
   r@ ! r>                              \ use HLD cell for extracting bytes
   count >r  count >r  c@               \ high | R: hld final low med
   SPIxfer drop                         \ assuming a little-endian model
   r> SPIxfer drop
   r> r> + SPIxfer drop
   r> hld !                             \ untrash hld
;
hex
: SPISR  \ -- status
   5 SPIxfer drop                       \ read status register
   1FF SPIxfer                          \ LSB is `busy`, bit1 is WEN
;
: SPIwait  \ --
   begin  SPISR 1 and 0=  until         \ spin loop does not pause
;
: SPIID  \ -- mfr type capacity
   9F SPIxfer                           \ JEDEC attempt at a standard
   dup xor  SPIxfer                     \ ended up vendor defined.
   dup xor  SPIxfer                     \ Refer to datasheets.
   dup xor  SPIxfer
;
: SPIerase4K  \ addr --                 \ erase 4K sector
   106 SPIxfer drop                     \ WREN
   20 100 SPIaddress
   104 SPIxfer drop                     \ WRDI
   SPIwait
;
: _SPImove  \ asrc adest len -- asrc'   \ write byte array to flash
   106 SPIxfer drop                     \ WREN
   swap 2 0 SPIaddress                  \ start page write command
   begin                                \ as len
      1- >r count                       \ as c | len
      r@ 0= if                          \ finished
         100 + SPIxfer drop
         104 SPIxfer drop               \ WRDI
         SPIwait
         r> drop exit
      then
      SPIxfer drop r>
   again
;
\ Break up page writes, if necessary, to avoid crossing 256-byte page boundaries
: SPImove  \ asrc adest len --          \ byte array to flash
   begin
      dup ifz: 3drop exit |             \ nothing left to move
      over invert 0FF and 1+            \ bytes to end of destination page
      over >r  min >r                   \ as ad | len sublen
      tuck r@ _SPImove                  \ ad as' | len sublen
      swap r@ +  r> r> swap -
   again
;
: SPI!  \ n addr --                     \ store one cell
   swap hld !
   hld swap 4 SPImove
;

: SPIbyte  \ a -- a+1
   0FF SPIxfer swap c!+
;

\ @ should already do this, but SPI@ operates the SPI to test the interface.
: SPI@  \ addr -- x                     \ 32-bit fetch
   0B 0 SPIaddress  dup SPIxfer drop    \ command and dummy byte
   hld  SPIbyte SPIbyte SPIbyte SPIbyte drop
   1FF SPIxfer drop                     \ end the command
   hld @
;
decimal

\ used SPI flash commands:
\ 0x05 RDSR   opcd -- n1
\ 0x0B FR     opcd A2 A1 A0 xx -- data...
\ 0x02 PP     opcd A2 A1 A0 d0 d1 d2 ...
\ 0x20 SER4K  opcd A2 A1 A0
\ 0x06 WREN   opcd
\ 0x04 WRDI   opcd
\ 0x9F RDJDID opcd -- n1 n2 n3