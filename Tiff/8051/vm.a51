;32-bit Virtual Machine and application ROM for 8051, flavor SiLabs EFM8LB1.
;Code generated by Tiff using template.A51 -- don't edit this file.

;The VM model interfaces with Keil C51 C functions, which use R4R5R6R7 as the
;return value as well as the _long_ non-pointer first parameter.
;The first pointer parameter is R2R1R0.

$NOMOD51
#include "SI_EFM8LB1_Defs.inc"
XRAMsize    EQU 1000H                  ;XRAM size of MCU in bytes

;The VM's USER function is free to trash the registers since it's the last
;executed slot. Otherwise, the VM uses R0-R3 as scratchpad.
;The RAM (with RAMsize 32-bit words) is implemented in XRAM.
;XRAMsize is used to place the VM's RAM at the top of XRAM. The linker will see it.

ROMsize     EQU 474 ;longs in ROM (at end of this file)

;-------------------------------------------------------------------------------
;The Keil C51/A51 compiler (assembled code/data) is big endian.
;The VM (code, stack and data space) is little endian.
;IRAM data is big endian, XRAM (and all other) data is little endian.

            NAME VMstuff

            PUBLIC _VM                  ;uint32_t VM(uint32_t IR);
            PUBLIC VMpor                ;void VMpor(void);

ExtFnTable  EQU 0x00A0

;Absolute XDATA is used for the RAM of the VM.
            XSEG AT XRAMsize - (4*1024)
RAM:        DS 4*1024
;Size is assumed to be a power-of-2 multiple of 256-byte pages in size.
;This allows a byte-wide bit mask to wrap the RAM address.
RAMpages:   EQU 1024/64


?ID?VM      SEGMENT DATA                ;Direct RAM
?BI?VM      SEGMENT BIT                 ;Bit space
?PR?VM      SEGMENT CODE                ;Code space

            RSEG ?ID?VM

T:          DS 4                        ;top of stack
N:          DS 4                        ;next on stack
PC:         DS 4                        ;program counter
DebugReg:   DS 4
IR:         DS 4                        ;instruction register
RP:         DS 2                        ;return stack pointer = 64
SP:         DS 2                        ;return stack pointer = 32
UP:         DS 2                        ;return stack pointer = 64
Scratch:    DS 7                        ;scratchpad storage
Temp:       DS 1                        ;more scratchpad
NEXTSLOT:   DS 1                        ;state for slot jump
SLOTID:     DS 1                        ;slot ID for IMM mask lookup

            RSEG ?BI?VM
CARRY:      DS 1                        ;carry flag

;-------------------------------------------------------------------------------

            RSEG ?PR?VM
            USING 0
VMinitTable:
            DW RAM+64, RAM+32, RAM+64   ;registers for VM

VMpor:      MOV R0, #T                  ;-> first Direct RAM
            MOV R1, #16
            CLR A
VMpor0:         MOV @R0, A              ;clear first 4 longs
                INC R0
                DJNZ R1, VMpor0
            MOV DPTR, #VMinitTable
            MOV R1, #6
VMpor1:         CLR A                   ;load 3 halfwords from table
                MOVC A, @A+DPTR
                INC DPTR
                MOV @R0, A
                INC R0
                DJNZ R1, VMpor1
            MOV DPTR, #RAM              ;clear all of RAM
            MOV R2, #RAMpages
            CLR A
VMpor2:         MOVX @DPTR, A           ;clear page
                DJNZ R1, VMpor1
                DJNZ R2, VMpor1
            RET

;-------------------------------------------------------------------------------

;uint32_t VM(uint32_t IR); IR is in r4r5r6r7. For speed, unwind short loops.
            MOV IR, R4                  ;get IR
            MOV IR+1, R5
            MOV IR+2, R6
            MOV IR+3, R7
            MOV R4, T
            MOV R5, T+1
            MOV R6, T+2
            MOV R7, T+3
            INC PC+3                    ;PC++
            JNC NEXT
            INC PC+2
            JNC NEXT
            INC PC+1
            JNC NEXT
            INC PC
            MOV NEXTSLOT, #0
NEXT:	    MOV DPTR, #SLOT0
            MOV A, NEXTSLOT
            JMP @A+DPTR
SLOT0:      MOV A, IR
            RRC A
            RRC A
            MOV NEXTSLOT, #SLOT1-SLOT0
            MOV SLOTID, #0
            SJMP DISPATCH
SLOT1:      MOV A, IR1
            SWAP A
            ANL A, #0FH
            MOV R0, A
            MOV A, IR0
            SWAP A
            ANL A, #30H
            ORL A, R0
            MOV NEXTSLOT, #SLOT2-SLOT0
            MOV SLOTID, #1
            SJMP DISPATCH
SLOT2:      MOV A, IR1
            RLC A
            RLC A
            ANL A, #3CH
            MOV R0, A
            MOV A, IR2
            RRC A
            RRC A
            SWAP A
            ANL A, #3
            ORL A, R0
            MOV NEXTSLOT, #SLOT3-SLOT0
            MOV SLOTID, #2
            SJMP DISPATCH
SLOT3:	    MOV A, IR2
            MOV NEXTSLOT, #SLOT4-SLOT0
            MOV SLOTID, #3
            SJMP DISPATCH
SLOT4:	    MOV A, IR3
            RRC A
            RRC A
            MOV NEXTSLOT, #SLOT5-SLOT0
            MOV SLOTID, #4
            SJMP DISPATCH
SLOT5:      MOV A, IR3
            ANL A, #3
            MOV NEXTSLOT, #SLOT6-SLOT0
            MOV SLOTID, #6
            SJMP DISPATCH
EX:
SLOT6:      MOV T, R4
            MOV T+1, R5
            MOV T+2, R6
            MOV T+3, R7
            MOV R4, PC
            MOV R5, PC+1
            MOV R6, PC+2
            MOV R7, PC+3
            RET
;64-way jump uses a table of LJMP to functions. All functions jump to NEXT.
DISPATCH:   ;ACC = ??oooooo where oooooo is a 6-bit opcode
            ANL A, #63
            MOV R3, A
            ADD A, ACC
            ADD A, R3
            MOV DPTR, #JumpTable
            JMP @A+DPTR

JumpTable:  LJMP NEXT         ;(000)  // nop
            LJMP opDUP        ;(001)  // dup
            LJMP opEXIT       ;(002)  // exit
            LJMP opADD        ;(003)  // +
            LJMP opUSER       ;(004)  // user
            LJMP opZeroLess   ;(005)  // 0<
            LJMP opPOP        ;(006)  // r>
            LJMP opTwoDiv     ;(007)  // 2/

            LJMP opSKIPNC     ;(010)  // ifc:  slot=end if no carry
            LJMP opOnePlus    ;(011)  // 1+
            LJMP opSWAP       ;(012)  // swap
            LJMP opSUB        ;(013)  // -
            LJMP NEXT
            LJMP opCstorePlus ;(015)  // c!+  ( c a -- a+1 )
            LJMP opCfetchPlus ;(016)  // c@+  ( a -- a+1 c )
            LJMP opUtwoDiv    ;(017)  // u2/

            LJMP opSKIP       ;(020)  // no:  skip remaining slots
            LJMP opTwoPlus    ;(021)  // 2+
            LJMP opSKIPNZ     ;(022)  // ifz:
            LJMP opJUMP       ;(023)  // jmp
            LJMP NEXT
            LJMP opWstorePlus ;(025)  // w!+  ( n a -- a+2 )
            LJMP opWfetchPlus ;(026)  // w@+  ( a -- a+2 n )
            LJMP opAND        ;(027)  // and

            LJMP NEXT
            LJMP opLitX       ;(031)  // litx
            LJMP opPUSH       ;(032)  // >r
            LJMP opCALL       ;(033)  // call
            LJMP NEXT
            LJMP opZeroEquals ;(035)  // 0=
            LJMP opWfetch     ;(036)  // w@  ( a -- n )
            LJMP opXOR        ;(037)  // xor

            LJMP opREPT       ;(040)  // rept  slot=0
            LJMP opFourPlus   ;(041)  // 4+
            LJMP opOVER       ;(042)  // over
            LJMP opADDC       ;(043)  // c+  with carry in
            LJMP NEXT
            LJMP opStorePlus  ;(045)  // !+  ( n a -- a+4 )
            LJMP opFetchPlus  ;(046)  // @+  ( a -- a+4 n )
            LJMP opTwoStar    ;(047)  // 2*

            LJMP opMiREPT     ;(050)  // -rept  slot=0 if T < 0
            LJMP NEXT
            LJMP opRP         ;(052)  // rp
            LJMP opDROP       ;(053)  // drop
            LJMP NEXT
            LJMP opSetRP      ;(055)  // rp!
            LJMP opFetch      ;(056)  // @
            LJMP opTwoStarC   ;(057)  // 2*c

            LJMP opSKIPGE     ;(060)  // -if:  slot=end if T >= 0
            LJMP NEXT
            LJMP opSP         ;(062)  // sp
            LJMP opFetchAS    ;(063)  // @as
            LJMP opSetSP      ;(065)  // sp!
            LJMP opCfetch     ;(066)  // c@
            LJMP opPORT       ;(067)  // port  ( n -- m ) swap T with port

            LJMP opSKIPLT     ;(070)  // +if:  slot=end if T < 0
            LJMP opLIT        ;(071)  // lit
            LJMP opUP         ;(072)  // up
            LJMP opStoreAS    ;(073)  // !as
            LJMP NEXT
            LJMP opSetUP      ;(075)  // up!
            LJMP opRfetch     ;(076)  // r@
;           LJMP opCOM        ;(077)  // com
            MOV A, R7
            CPL A
            MOV R7, A
            MOV A, R6
            CPL A
            MOV R6, A
            MOV A, R5
            CPL A
            MOV R5, A
            MOV A, R4
            CPL A
            MOV R4, A
            LJMP NEXT


;Common stack operations are the same as in the C model.
;The stack pointers are indices to longs. RAMsize is in longs.

SDUP:       MOV A, #SP                  ;{ RAM[--SP & (RAMsize-1)] = N;  N = T; }
            MOV R0, A                   ;-> high byte
            INC A
            MOV R1, A                   ;-> low byte
            LCALL XDUP                  ;get DPTR
            MOV R0, #N+3
            LCALL R0TORAM               ;write N to XRAM
            MOV N, T
            MOV N+1, T+1
            MOV N+2, T+2
            MOV N+3, T+3
            RET

RDUP:       PUSH ACC                    ;A points to x in IRAM
            MOV A, #RP                  ;{ RAM[--RP & (RAMsize-1)] = x; }
            MOV R0, A                   ;-> high byte
            INC A
            MOV R1, A                   ;-> low byte
            LCALL XDUP                  ;get DPTR
            POP ACC
            MOV R0, A                   ;write x to XRAM
R0TORAM:    MOV A, @R0
            DEC R0
            MOVX @DPTR, A
            INC DPTR
            MOV A, @R0
            DEC R0
            MOVX @DPTR, A
            INC DPTR
            MOV A, @R0
            DEC R0
            MOVX @DPTR, A
            INC DPTR
            MOV A, @R0
            DEC R0
            MOVX @DPTR, A
            RET

XDUP:       MOV A, @R0                  ;predecrement pointer
            JNZ XDUP0
            DEC @R0
XDUP0:      DEC @R1

XPTR:       MOV A, @R1                  ;DPTR = (4*pointer & RAMpages-1) + RAM
            RLC A
            MOV R3, A
            MOV A, @R0
            RLC A
            MOV R2, A
            MOV A, R3
            RLC A
            ANL A, 0C0H
            MOV DPL, A
            MOV A, R2
            RLC A
            ANL A, #RAMpages-1
            ADD A, #HIGH(RAM)
            MOV DPH, A
            RET

SDROP:      MOV T, N                    ;{ T = N;  N = RAM[SP++ & (RAMsize-1)]; }
            MOV T+1, N+1
            MOV T+2, N+2
            MOV T+3, N+3
SNIP:       MOV A, #SP                  ;{ N = RAM[SP++ & (RAMsize-1)]; }
            MOV R0, A                   ;-> high byte
            INC A
            MOV R1, A                   ;-> low byte
            MOV Temp, #N+3
XNIP:       LCALL XPTR                  ;get DPTR
            MOV A, R0
            PUSH ACC                    ;keep R0
            MOV R0, Temp
            LCALL RAMTOR0               ;N = RAM
            POP ACC
            MOV R0, A
            INC @R1                     ;post-increment pointer
            JNC XNIPX
            INC @R0
XNIPX:      RET

RDROP:      MOV A, #RP                  ;{ IRAM[Temp] = RAM[RP++ & (RAMsize-1)]; }
            MOV R0, A                   ;-> high byte
            INC A
            MOV R1, A                   ;-> low byte
            SJMP XNIP

RAMTOR0:    MOVX A, @DPTR               ;XRAM to @R0
            INC DPTR
            MOV @R0, A
            DEC R0
            MOVX A, @DPTR
            INC DPTR
            MOV @R0, A
            DEC R0
            MOVX A, @DPTR
            INC DPTR
            MOV @R0, A
            DEC R0
            MOVX A, @DPTR
            INC DPTR
            MOV @R0, A
            RET

CELLDIV2:   MOV A, @R0                  ;IRAM[R0] /= 2
            CLR C
            RRC A
            MOV @R0, A
            INC R0
            MOV A, @R0
            RRC A
            MOV @R0, A
            INC R0
            MOV A, @R0
            RRC A
            MOV @R0, A
            INC R0
            MOV A, @R0
            RRC A
            MOV @R0, A
            RET

;IMM is (IR & ~(-1<<slot))
IMMmasks:   DL 03FFFFFFH
            DL 000FFFFFH
            DL 00003FFFH
            DL 000000FFH
            DL 00000003H

;IMM is IR & IMMmask.
;Since all IMM users won't need the IR anymore, IMM (unsigned data) is put in IR.
GetIMM:     MOV R0, #IR
            MOV DPTR, IMMmasks
            MOV A, SLOTID
            RLC A
            RLC A
            ANL A, #03CH
            MOV R1, A
            MOVC A, @A+DPTR
            ANL A, @R0
            MOV @R0, A
            INC R0
            INC R1
            MOV A, R1
            MOVC A, @A+DPTR
            ANL A, @R0
            MOV @R0, A
            INC R0
            INC R1
            MOV A, R1
            MOVC A, @A+DPTR
            ANL A, @R0
            MOV @R0, A
            INC R0
            INC R1
            MOV A, R1
            MOVC A, @A+DPTR
            ANL A, @R0
            MOV @R0, A
            RET

;-------------------------------------------------------------------------------
;Opcodes

opDUP:      LCALL SDUP
            LJMP NEXT

opEXIT:     MOV Temp, #PC
            LCALL RDROP
            MOV R0, #PC
            LCALL CELLDIV2
            MOV R0, #PC
            LCALL CELLDIV2
            LJMP NEXT

opADD:      MOV A, N+3
            ADD A, T+3
            MOV T+3, A
            MOV A, N+2
            ADDC A, T+2
            MOV T+2, A
            MOV A, N+1
            ADDC A, T+1
            MOV T+1, A
            MOV A, N
            ADDC A, T
            MOV T, A
            MOV CARRY, C
            LCALL SNIP
            LJMP NEXT


opUSER:
			case opUSER: M = UserFunction (T, N, IMM);          // user
                T = M;  goto ex;


opZeroLess:
opPOP:
opTwoDiv:

opSKIPNC:
opOnePlus:
opSWAP:
opSUB:

opCstorePlus
opCfetchPlus
opUtwoDiv

opSKIP          LJMP EX

opTwoPlus
opSKIPNZ
opJUMP

opWstorePlus
opWfetchPlus
opAND


opLitX
opPUSH
opCALL

opZeroEquals
opWfetch
opXOR

opREPT
opFourPlus
opOVER
opADDC

opStorePlus
opFetchPlus
opTwoStar

opMiREPT

opRP
opDROP


opFetch
opTwoStarC

opSKIPGE

opSP
opFetchAS
opSetSP
opCfetch
opPORT

opSKIPLT
opLIT
opUP
opStoreAS

opSetRP:    MOV Temp, #RP
            SJMP SetXP
opSetUP:    MOV Temp, #UP
SetXP:      MOV R0, #T
            LCALL CELLDIV2
            MOV R0, #T
            LCALL CELLDIV2
            MOV R0, Temp
            MOV A, T+2
            MOV @R0, A
            INC R0
            MOV A, T+3
            MOV @R0, A
            LCALL SDROP
            LJMP NEXT

opSetSP:    MOV R0, #T
            LCALL CELLDIV2
            MOV R0, #T
            LCALL CELLDIV2
            MOV R0, #SP
            MOV A, T+2
            MOV @R0, A
            INC R0
            MOV A, T+3
            MOV @R0, A
            LCALL SDROP
            LJMP NEXT

opRfetch:   LCALL SDUP
            MOV Temp, #T+3
            LCALL RDROP
            LJMP NEXT



			case opUSER: M = UserFunction (T, N, IMM);          // user
#ifdef TRACEABLE
                Trace(New, RidT, T, M);  New=0;
#endif // TRACEABLE
                T = M;  goto ex;
			case opZeroLess:
                M=0;  if ((signed)T<0) M--;
#ifdef TRACEABLE
                Trace(New, RidT, T, M);  New=0;
#endif // TRACEABLE
                T = M;                                  break;  // 0<
			case opPOP:  SDUP();  M = RDROP();
#ifdef TRACEABLE
                Trace(0, RidT, T, M);
#endif // TRACEABLE
			    T = M;      				            break;	// r>
			case opTwoDiv:
#ifdef TRACEABLE
                Trace(New, RidT, T, T / 2);  New=0;
                Trace(0, RidCY, CARRY, T&1);
#endif // TRACEABLE
			    T = (signed)T / 2;  CARRY = T&1;        break;	// 2/
			case opSKIPNC: if (!CARRY) goto ex;	        break;	// ifc:
			case opOnePlus:
#ifdef TRACEABLE
                Trace(New, RidT, T, T + 1);  New=0;
#endif // TRACEABLE
			    T = T + 1;                              break;	// 1+
			case opPUSH:  RDUP(T);  SDROP();            break;  // >r
			case opSUB:
			    DX = (uint64_t)N - (uint64_t)T;
#ifdef TRACEABLE
                Trace(New, RidT, T, (uint32_t)DX);  New=0;
                Trace(0, RidCY, CARRY, ~(uint32_t)(DX>>32));
#endif // TRACEABLE
                T = (uint32_t)DX;
                CARRY = ~(uint32_t)(DX>>32);
                SNIP();	                                break;	// -
			case opCstorePlus:    /* ( n a -- a' ) */
                StoreX(T>>2, N, (T&3)*8, 0xFF);
#ifdef TRACEABLE
                Trace(0, RidT, T, T+1);
#endif // TRACEABLE
                T += 1;   SNIP();                       break;  // c!+
			case opCfetchPlus:  SDUP();  /* ( a -- a' c ) */
                M = FetchX(N>>2, (N&3) * 8, 0xFF);
#ifdef TRACEABLE
                Trace(0, RidT, T, M);
                Trace(0, RidN, N, N+1);
#endif // TRACEABLE
                T = M;
                N += 1;                                 break;  // c@+
			case opUtwoDiv:
#ifdef TRACEABLE
                Trace(New, RidT, T, (unsigned) T / 2);  New=0;
                Trace(0, RidCY, CARRY, T&1);
#endif // TRACEABLE
			    T = T / 2;   CARRY = T&1;               break;	// u2/
			case opTwoPlus:
#ifdef TRACEABLE
                Trace(New, RidT, T, T + 2);  New=0;
#endif // TRACEABLE
			    T = T + 2;                              break;	// 2+
			case opOVER: M = N;  SDUP();
#ifdef TRACEABLE
                Trace(0, RidT, T, M);
#endif // TRACEABLE
                T = M;				                    break;	// over
			case opJUMP:
#ifdef TRACEABLE
                Trace(New, RidPC, PC, IMM);  New=0;
                if (!Paused) cyclecount += 3;
				// PC change flushes pipeline in HW version
#endif // TRACEABLE
                // Jumps and calls use cell addressing
			    PC = IMM;  goto ex;                             // jmp
			case opWstorePlus:    /* ( n a -- a' ) */
                StoreX(T>>2, N, (T&2)*8, 0xFFFF);
#ifdef TRACEABLE
                Trace(0, RidT, T, T+2);
#endif // TRACEABLE
                T += 2;   SNIP();                       break;  // w!+
			case opWfetchPlus:  SDUP();  /* ( a -- a' c ) */
                M = FetchX(N>>2, (N&2) * 8, 0xFFFF);
#ifdef TRACEABLE
                Trace(0, RidT, T, M);
                Trace(0, RidN, N, N+2);
#endif // TRACEABLE
                T = M;
                N += 2;                                 break;  // w@+
			case opAND:
#ifdef TRACEABLE
                Trace(New, RidT, T, T & N);  New=0;
#endif // TRACEABLE
                T = T & N;  SNIP();	                    break;	// and
            case opLitX:
				M = (T<<24) | (IMM & 0xFFFFFF);
#ifdef TRACEABLE
                Trace(New, RidT, T, M);  New=0;
#endif // TRACEABLE
                T = M;
                goto ex;                                        // litx
			case opSWAP: M = N;                                 // swap
#ifdef TRACEABLE
                Trace(New, RidN, N, T);  N = T;  New=0;
                Trace(0, RidT, T, M);    T = M;         break;
#else
                N = T;  T = M;  break;
#endif // TRACEABLE
			case opCALL:  RDUP(PC<<2);                        	// call
#ifdef TRACEABLE
                Trace(0, RidPC, PC, IMM);  PC = IMM;
                if (!Paused) cyclecount += 3;
                goto ex;
#else
                PC = IMM;  goto ex;
#endif // TRACEABLE
            case opZeroEquals:
                M=0;  if (T==0) M--;
#ifdef TRACEABLE
                Trace(New, RidT, T, M);  New=0;
#endif // TRACEABLE
                T = M;                                  break;  // 0=
			case opWfetch:  /* ( a -- w ) */
                M = FetchX(T>>2, (T&2) * 8, 0xFFFF);
#ifdef TRACEABLE
                Trace(0, RidT, T, M);
#endif // TRACEABLE
                T = M;                                  break;  // w@
			case opXOR:
#ifdef TRACEABLE
                Trace(New, RidT, T, T ^ N);  New=0;
#endif // TRACEABLE
                T = T ^ N;  SNIP();	                    break;	// xor
			case opREPT:  slot = 32;                    break;	// rept
			case opFourPlus:
#ifdef TRACEABLE
                Trace(New, RidT, T, T + 4);  New=0;
#endif // TRACEABLE
			    T = T + 4;                              break;	// 4+
            case opSKIPNZ:
				M = T;  SDROP();
                if (M == 0) break;
                goto ex;  										// ifz:
			case opADDC:  // carry into adder
			    DX = (uint64_t)N + (uint64_t)T + (uint64_t)(CARRY & 1);
#ifdef TRACEABLE
                Trace(New, RidT, T, (uint32_t)DX);  New=0;
                Trace(0, RidCY, CARRY, (uint32_t)(DX>>32));
#endif // TRACEABLE
                T = (uint32_t)DX;
                CARRY = (uint32_t)(DX>>32);
                SNIP();	                                break;	// c+
			case opStorePlus:    /* ( n a -- a' ) */
                StoreX(T>>2, N, 0, 0xFFFFFFFF);
#ifdef TRACEABLE
                Trace(0, RidT, T, T+4);
#endif // TRACEABLE
                T += 4;   SNIP();                       break;  // !+
			case opFetchPlus:  SDUP();  /* ( a -- a' c ) */
                M = FetchX(N>>2, 0, 0xFFFFFFFF);
#ifdef TRACEABLE
                Trace(0, RidT, T, M);
                Trace(0, RidN, N, N+4);
#endif // TRACEABLE
                T = M;
                N += 4;                                 break;  // @+
			case opTwoStar:
                M = T * 2;
#ifdef TRACEABLE
                Trace(0, RidT, T, M);
                Trace(0, RidCY, CARRY, T>>31);
#endif // TRACEABLE
                CARRY = T>>31;   T = M;                 break;  // 2*
			case opMiREPT:
                if (N&0x8000) slot = 32;          	            // -rept
#ifdef TRACEABLE
                Trace(New, RidN, N, N+1);  New=0; // repeat loop uses N
#endif // TRACEABLE                               // test and increment
                N++;  break;
			case opRP: M = RP;                                  // rp
                goto GetPointer;
			case opDROP: SDROP();		    	        break;	// drop
			case opFetch:  /* ( a -- n ) */
                M = FetchX(T>>2, 0, 0xFFFFFFFF);
#ifdef TRACEABLE
                Trace(0, RidT, T, M);
#endif // TRACEABLE
                T = M;                                  break;  // @
            case opTwoStarC:
                M = (T*2) | (CARRY&1);
#ifdef TRACEABLE
                Trace(0, RidT, T, M);
                Trace(0, RidCY, CARRY, T>>31);

#endif // TRACEABLE
                CARRY = T>>31;   T = M;                 break;  // 2*c
			case opSKIPGE: if ((signed)T < 0) break;            // -if:
                goto ex;
			case opSP: M = SP;                                  // sp
GetPointer:     M = T + (M + ROMsize)*4;
#ifdef TRACEABLE
                Trace(0, RidT, T, M);
#endif // TRACEABLE
			    T = M;                                  break;
			case opFetchAS:
                ReceiveAXI(N/4, T/4, IMM);  goto ex;	        // @as
			case opCfetch:  /* ( a -- w ) */
                M = FetchX(T>>2, (T&3) * 8, 0xFF);
#ifdef TRACEABLE
                Trace(0, RidT, T, M);
#endif // TRACEABLE
                T = M;                                  break;  // c@
			case opPORT: M = T;
#ifdef TRACEABLE
                Trace(0, RidT, T, DebugReg);
                Trace(0, RidDbg, DebugReg, M);
#endif // TRACEABLE
                T=DebugReg;
                DebugReg=M;
                break;	// port
			case opSKIPLT: if ((signed)T >= 0) break;           // +if:
                goto ex;
			case opLIT: SDUP();
#ifdef TRACEABLE
                Trace(0, RidT, T, IMM);
#endif // TRACEABLE
                T = IMM;  goto ex;                              // lit
			case opUP: M = UP;  	                            // up
                goto GetPointer;
			case opStoreAS:  // ( src dest -- src dest ) imm length
                SendAXI(N/4, T/4, IMM);  goto ex;               // !as
			case opSetUP:
                M = (T>>2) & (RAMsize-1);
			    UP = M;  SDROP();	                    break;	// up!
			case opRfetch:

END
