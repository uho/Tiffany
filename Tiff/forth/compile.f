\ compiler (not tested yet)
\ incomplete

\ Code and headers are both in flash. Write using SPI!.

: aligned  3 + -4 and ;                 \ a -- a'
: ,   cp dup >r  @ SPI!  4 r> +! ;
: ,h  hp dup >r  @ SPI!  4 r> +! ;


\ Define a compiler
\ char params:  c_colondef c_litpend c_slot c_called

defer FlushLit
defer NewGroup

: ClearIR   \ --                        \ Initialize the IR. slot=26, litpend=0
   0 iracc !  26 c_slot w!  0 c_called c!
;
: AppendIR  \ opcode imm                \ insert opcode at slot, adding imm
   swap  c_slot c@ lshift  iracc @      \ shift it and get IR
   +  +                    iracc !      \ merge into instruction
;

: Implicit  \ opcode                    \ add implicit opcode to group
   FlushLit
   c_slot c@ 0=  over 60 and  and if    \ doesn't fit in the last slot
      NewGroup
   then
   0 AppendIR
   c_slot c@  dup if
      6 - -if: dup xor |                \ sequence: 26, 20, 14, 8, 2, 0
      c_slot c! exit
   then
   drop NewGroup                        \ slot 0 -> slot 26
;

: Explicit  \ opcode imm
   FlushLit
   1  c_slot c@  dup >r  lshift         \ opcode imm maximum
   over 1+ - 0<  r> 0=
   + 0= |ifz NewGroup |                 \ it doesn't fit
   AppendIR
   c_slot c@  24 lshift
   cp @ +  calladdr !                   \ remember call address in case of ;
   0 c_slot c!  NewGroup
;

: HardLit  \ n --                       \ compile a hard literal
   dup >r -if: negate |                 \ u
   dup 33554431 invert 2* and if        \ too wide
      r> drop op_lit  over 24 rshift  Explicit   \ upper part
      op_litx swap    16777215 and    Explicit   \ lower part
      exit
   then
   r> 0< if
      1- op_lit swap Explicit
      op_com Implicit  exit
   then
   op_lit swap Explicit
;

:noname \ FlushLit  \ --                \ compile a literal if it's pending
   c_litpend c@ if
      0 c_litpend c!
      nextlit @ HardLit
   then
   0 c_called c!                        \ everything clears the call tail
; is FlushLit

:noname \ NewGroup  \ --                \ finish the group and start a new one
    FlushLit                            \ if a literal is pending, compile it
    c_slot c@
    dup 21 - +if: 2drop exit |          \ already at first slot
    drop if
       op_no: Implicit                  \ skip unused slots
    then
    iracc @ ,
    ClearIR
; is NewGroup

: litral  \ n --
   FlushLit
   dup 33554431 invert 2* and
   if HardLit exit then
   nextlit !  1 c_litpend c!
;

\ untested...

: compile,  \ xt --
   head @ 4 + c@  128 and  c_called c!  \ 0 = call-only
   op_call Explicit
;

: ,exit  \ --
   c_called c@ if
      calladdr link>
      8  [ calladdr 3 + ] literal c@  lshift
      invert swap SPI!                  \ convert CALL to JUMP
      0 c_called c!
      0 calladdr ! exit
   then op_exit Implicit
;

: ,;  \ --
   ,exit  NewGroup
   current @ @                          \ link
   dup 4 + @ 32 and if                  \ smudge bit is set?
      dup 4 + 32 invert SPI!            \ clear it
   then
   c_colondef c@ if                     \ wid
      0 c_colondef c!
      cp @  over 4 - link>  2/ 2/       \ length
      255 min
      pad c!  pad swap 1 SPImove
   then
   0 state !
;

