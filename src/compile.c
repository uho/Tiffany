
#include <stdio.h>
#include <stdlib.h>
#include "vm.h"
#include "accessvm.h"
#include "compile.h"
#include "tiff.h"
#include "colors.h"
#include <string.h>
#define RunLimit 50000000

/// The compiler keeps all state inside the VM when compiling code
/// so that executable code can take over later by redirecting
/// the header's xtc and xte.

// Hopefully, all of the opcode dependencies are in this file.

static void FlushLit (void);            // forward reference
uint32_t OpcodeCount[64];               // static instruction count

static char names[64][6] = {
    ".",     "dup",  "exit",  "+",    "2*",   "?",    "?",   "?",
    "_",     "1+",   "r>",    "?",    "2*c",  "user", "c@+", "c!+",
    "?",     "rp",   "r@",    "and",  "2/",   "jmp",  "w@+", "w!+",
    "?",     "sp",   "?",     "xor",  "u2/",  "call", "w@",  ">r",
    "reptc", "4+",   "?",     "c+",   "0=",   "litx", "@+",  "!+",
    "-rept", "up",   "?",     "?",    "0<",   "?",    "@",   "rp!",
    "-if:",  "port", "?",     "?",    "com",  "user", "c@",  "sp!",
    "ifc:",  "over", "ifz:",  "drop", "swap", "lit",  "?",   "up!"
};

char * OpName(unsigned int opcode) {
    return names[opcode&0x3F];
}

// Determine if opcode uses immediate data
static int isImmediate(unsigned int opcode) {
    switch (opcode) {
        case opLitX:
        case opLIT:
        case opHost:
        case opUSER:
        case opCALL:
        case opJUMP: return 1;
        default: return 0;
    }
}
// Determine if opcode uses immediate address
static int isImmAddress(unsigned int opcode) {
    switch (opcode) {
        case opCALL:
        case opJUMP: return 1;
        default: return 0;
    }
}

uint32_t DisassembleIR(uint32_t IR) {  // return imm if JMP
    int slot = 26;  // 26 20 14 8 2
    int opcode;
    uint32_t r = 0;
    while (slot>=0) {
        opcode = (IR >> slot) & 0x3F;
        r = 0;
        NextOp: if (isImmediate(opcode)) {
            uint32_t imm = IR & ~(0xFFFFFFFF << slot);
            if (isImmAddress(opcode)) {
                r = imm<<2;
                char *name = GetXtName(r);
                if (name) {
                    ColorCompiled();
                    printf("%s ", name);
                } else {
                    ColorImmAddress();
                    printf("0x%X ", r);
                }
            } else {
                ColorImmediate();
                printf("0x%X ", imm);
            }
            slot=0;
        }
        ColorOpcode();
        printf("%s ", OpName(opcode));
        slot -= 6;
    }
    if (slot == -4) {
        opcode = IR & 3;
        goto NextOp;
    }
    ColorNormal();
    return r;
}

void ListOpcodeCounts(void) {           // list the opcode profiles
    int i;                              // in csv format
    printf("\n\"Static Instruction Counts\"");
    for (i=0; i<64; i++){
        printf("\n%d,\"%s\",%d", i, OpName(i), OpcodeCount[i]);
    }
	#ifdef TRACEABLE
    printf("\n\"Dynamic Instruction Counts\"");
    for (i=0; i<64; i++){
        printf("\n%d,\"%s\",%u", i, OpName(i), OpCounter[i]);
    }
    memset(OpCounter,0,64*sizeof(uint32_t)); // clear afterwards
	#endif
}

void ListProfile(void) {                // list the execution profile
	#ifdef TRACEABLE                    // in csv format
    printf("\n\"Addr\",\"Hits\"");
    int last = ROMsize;
    while (--last) {                    // end of internal ROM
        if (ProfileCounts[last] != 0) break;
    }
    for (int i=0; i<last; i++){
        printf("\n\"%04Xh\",%u", i*4, ProfileCounts[i]);
    }
    memset(ProfileCounts, 0, ROMsize*sizeof(uint32_t));  // clear afterwards
    #else
    printf("\nNot supported");
	#endif
}

void InitIR (void) {                    // initialize the IR
    StoreCell(0, IRACC);
    StoreHalf(26, SLOT);                // SLOT=26, LITPEND=0
    StoreByte(0, CALLED);
}

static void AppendIR (unsigned int opcode, uint32_t imm) {
    uint32_t ir = FetchCell(IRACC);
    ir = ir + (opcode << FetchByte(SLOT)) + imm;
    StoreCell(ir, IRACC);
    OpcodeCount[opcode&0x3F]++;
}

// Append a zero-operand opcode
// Slot positions are 26, 20, 14, 8, 2, and 0

static void Implicit (int opcode) {
    FlushLit();
    if ((FetchByte(SLOT) == 0) && (opcode > 3))
        NewGroup();                     // doesn't fit in the last slot
    AppendIR(opcode, 0);
    int8_t slot = FetchByte(SLOT);
    if (slot) {
        slot -= 6;
        if (slot < 0) slot = 0;
        StoreByte(slot, SLOT);
    } else {
        NewGroup();
    }
}

// Finish off IR with the largest literal that will fit.
// All literals are unsigned.

static void Explicit (int opcode, uint32_t n) {
    FlushLit();
    int8_t slot = FetchByte(SLOT);
    if ((n >= (1 << slot)) || (slot == 0))
        NewGroup();                     // it doesn't fit
    AppendIR(opcode, n);
    StoreCell((FetchByte(SLOT) << 24) + FetchCell(CP), CALLADDR);
    StoreByte(0, SLOT);
    NewGroup();
}

void NewGroup (void) {                  // finish the group and start a new one
    FlushLit();                         // if a literal is pending, compile it
    uint8_t slot = FetchByte(SLOT);
    if (slot > 20) return;              // already at first slot
    if (slot > 0) Implicit(opSKIP);     // skip unused slots
    CommaC(FetchCell(IRACC));
    InitIR();
}

////////////////////////////////////////////////////////////////////////////////
// Tail-call optimization requires knowing the address of the instruction
// containing the call as well as its slot number. It makes certain assumptions
// about opcodes. CALL is 074, JUMP is 064 octal (111100 and 110100 binary).
// See tiffCOLON.

// notail not implemented yet

static void CompCall (uint32_t addr, int notail) {
    uint8_t len = FetchByte(FetchCell(HEAD) + 4);
    Explicit(opCALL, addr/4);
    if ((len & 0x80) == 0) return;  // call-only bit is set
    StoreByte(1, CALLED);
}

void Compile (uint32_t addr) {          // the normal compile
    CompCall (addr, 0);
}

// Definitions that only use implicit opcodes are very easy to compile as
// macros.

static void CompileMacro(uint32_t addr) { // compile as a macro
    int i;  int opcode;  uint32_t ir;
    int slot = 26;
    for (i=0; i<20; i++) {                // limit length of macro
        if (slot == 26) {
            ir = FetchCell(addr);
            addr += 4;
        }
        if (slot < 0) {
            opcode = ir & 3;                // slot = -4
            slot = 26;
        } else {
            opcode = (ir >> slot) & 0x3F;   // slot = 26, 20, 14, 8, 2
            slot -= 6;
        }
        if (opcode == opEXIT) return;
        Implicit(opcode);
    } tiffIOR = -61;
}

// ; does several things:
// 1. Attempt to convert the last call to a jump.
// 2. Otherwise, append an EXIT and end the group.
// 3. Unsmudge the current header if it's smudged.
// 4. if COLONDEF, resolve the code length.
// 5. Return to EXECUTE mode.

void CompExit (void) {  /*EXPORT*/
	if (FetchByte(CALLED)) {            // ca = packed slot and address
        uint32_t ca = FetchCell(CALLADDR);
        uint32_t addr = ca & 0xFFFFFF;
        uint8_t slot = ca >> 24;
        uint32_t mask = ~(8 << slot);
        StoreROM(mask, addr);           // convert CALL to JUMP
        StoreCell(0, CALLADDR);         // clear ca
        StoreByte(0, CALLED);
	} else {
	    Implicit(opEXIT);
	}
}

void CompSemi (void) {  /*EXPORT*/
    CompExit();  NewGroup();
	uint32_t wid = FetchCell(CURRENT);
	wid = FetchCell(wid);               // -> current definition
    uint32_t name = FetchCell(wid + 4);
    if (name & 0x20) {                  // if the smudge bit is set
        StoreROM(~0x20, wid + 4);       // then clear it
    }
    // The code address is in the header at wid-16.
    if (FetchByte(COLONDEF)) {          // resolve length of definition
        StoreByte(0, COLONDEF);
        uint32_t org = FetchCell(wid-4) & 0xFFFFFF; // start address = xte
        uint32_t cp  = FetchCell(CP);     // end address
        uint32_t length = (cp - org) / 4; // length in cells
        if (length>255) length=255;       // limit to 8-bit
        StoreROM(length + 0xFFFF0000, wid - 12);
    }
    StoreCell(0, STATE);
}

////////////////////////////////////////////////////////////////////////////////

static void HardLit (int32_t N) {
    uint32_t u = abs(N);
    if (u < 0x03FFFFFF) {               // single width literal
        if (N < 0) {
            Explicit(opLIT, u-1);       // negative number
            Implicit(opCOM);
        } else {
            Explicit(opLIT, u);
        }
    } else {
        Explicit(opLIT, ((N>>24) & 0xFF)); // split into 8 and 24
        Explicit(opLitX, (N & 0xFFFFFF));
    }
}

static void FlushLit(void) {            // compile a literal if it's pending
    if (FetchByte(LITPEND)) {
        StoreByte(0, LITPEND);
        HardLit(FetchCell(NEXTLIT));
    }
    StoreByte(0, CALLED);               // everything clears the call tail
}

void Literal (uint32_t N) { /*EXPORT*/  // cache the newest literal
    FlushLit();
    if (N < 0x4000000) {
        StoreCell(N, NEXTLIT);
        StoreByte(1, LITPEND);
    } else HardLit(N);                  // large literal doesn't cache
}

static void Immediate (uint32_t op) {   // expecting cached immediate data
    if (FetchByte(LITPEND)) {
        StoreByte(0, LITPEND);
        Explicit(op, FetchCell(NEXTLIT));
    } else tiffIOR = -59;
}

static void SkipOp (uint32_t op) {      // put a skip opcode the next valid slot
    FlushLit();
	if (FetchByte(SLOT) < 8) NewGroup();
	Implicit(op);
}

static void HardSkipOp (uint32_t op) {  // put a skip opcode in a new group
	NewGroup();
	Implicit(op);
}

static void FakeIt (int opcode) {       // execute an opcode in the VM
    DbgGroup(opcode, opSKIP, opNOP, opNOP, opNOP);
}

void CompComma (void){                  // append number on the stack to code space
    uint32_t cp = FetchCell(CP);
    StoreROM(PopNum(), cp);
    if (cp & 3) tiffIOR = -23;          // not cell aligned
    StoreCell(cp+4, CP);
}
void XcommaC (uint8_t c, uint32_t pointer) {
    uint32_t p = FetchCell(pointer);
    uint32_t addr = p & ~3;
    uint32_t x = ~((0xFF&(~c)) << (8*(p&3))); // align c, all other are '1's
    StoreROM(x, addr);
    StoreCell(p+1, pointer);
}

void CompCommaC (void){
    XcommaC(PopNum(), CP);
}
// pointer is HP or CP
// mode bits usage: 11:4 = flags, 2 = not-escaped, 1 = cell-align, 0 = counted
void CompString(char *s, int mode, int32_t pointer) {
    int length = strlen(s);
    uint32_t mark = FetchCell(pointer); // Address of byte to resolve
    char hex[4];
    int cnt = 0;
    if (mode & 1) {                     // skip count
        StoreCell(mark+1, pointer);
    }
    for (int i=0; i<length; i++) {
        char c = *s++;
        if (0 == (mode & 4)) {          // escape sequences supported
            if (c == '\\') {
                c = *s++;
                length--;
                switch (c) {
                    case 'a': c = 7;   break;  // BEL  (bell)
                    case 'b': c = 8;   break;  // BS (backspace)
                    case 'e': c = 27;  break;  // ESC (not in C99)
                    case 'f': c = 12;  break;  // FF (form feed)
                    case 'l': c = 10;  break;  // LF
                    case 'n': c = 10;  break;  // newline
                    case 'q': c = '"'; break;  // double-quote
                    case 'r': c = 13;  break;  // CR
                    case 't': c = 9;   break;  // HT (tab)
                    case 'v': c = 11;  break;  // VT
                    case 'x': hex[2] = 0;  	   // hex byte
						hex[0] = *s++;
						hex[1] = *s++;
						c = (char)strtol(hex, (char **)NULL, 16); break;
                    case 'z': c = 0;   break;  // NUL
                    case '"': c = '"'; break;  // double-quote
                    default: break;
                }
            }
        }
        XcommaC(c, pointer);
        cnt++;
    }
    if (mode & 1) {                     // resolve count
        uint32_t temp = FetchCell(pointer);
        StoreCell(mark, pointer);
        XcommaC(cnt + (mode>>4), pointer);
        StoreCell(temp, pointer);
    }
    if (mode & 2) {                     // align afterwards
        uint32_t cp = FetchCell(pointer);
        StoreCell((cp+3) & (~3), pointer);
    }
}

// Compile branches: | 0= -bran <20-bit> |

void NoExecute (void) {
    if (!FetchCell(STATE)) tiffIOR = -14;
}
void CompLiteral (void){
    NoExecute(); Literal(PopNum());
}

void NeedSlot(int s) {
    NoExecute();
    uint32_t cp = FetchCell(CP);
    if (cp > 0xEFFF) s += 6;    // large address, leave room for >16-bit address
    if (FetchByte(SLOT)<s)  NewGroup();
}
void CompAhead (void){  // ( -- then )
    NeedSlot(14);
    uint32_t addr = FetchCell(CP);
    int slot = FetchByte(SLOT);
    PushNum(0x60000000 + (slot<<24) + addr);
    Explicit(opJUMP, ~(-1<<slot));
}
void CompIfX (int opcode){  // ( -- then )
    NeedSlot(20);
    uint32_t addr = FetchCell(CP);
    Implicit(opcode);
    int slot = FetchByte(SLOT);
    PushNum(0x60000000 + (slot<<24) + addr);
    Explicit(opJUMP, ~(-1<<slot));
}
void CompIfNC (void){  // ( -- then )
    CompIfX(opSKIPNC);
}
void CompIf (void){  // ( -- then )
    CompIfX(opSKIPNZ);
}
void CompPlusIf (void){  // ( -- then )
    CompIfX(opSKIPGE);
}

void CompThen (void){  // ( then -- )
    NewGroup();  NoExecute();
    uint32_t token = PopNum();
    uint32_t mark = token & 0xFFFFFF;
    if (!mark) return;          // skip if nothing to resolve
    int slot = token>>24;
    if ((slot>>5) != 3) {
        tiffIOR = -22;
    }
    slot &= 0x1F;
    uint32_t dest = FetchCell(CP) >> 2;
//  printf("\nFwd Resolving %X = %X, slot %d ", mark, dest, slot);
    StoreROM((-1<<slot) + dest, mark);
}
void CompElse (void){  // ( then -- then' )
    NewGroup();  NoExecute();
    uint32_t cp =   FetchCell(CP);
    uint32_t slot = FetchByte(SLOT);
    Explicit(opJUMP, 0x3FFFFFF);
    CompThen();
    PushNum(0x60000000 + (slot<<24) + cp);
}
void CompBegin (void){  // ( -- again )
    NewGroup();  NoExecute();
    PushNum(FetchCell(CP));
}
void CompAgain (void){  // ( then -- )
    NoExecute();
    uint32_t dest = PopNum();
    Explicit(opJUMP, dest>>2);
}
void CompWhile (void){  // ( then -- then again )
    uint32_t beg = PopNum();
    CompIf();
    PushNum(beg);
}
void CompPlusWhile (void){  // ( then -- then again )
    uint32_t beg = PopNum();
    CompPlusIf();
    PushNum(beg);
}
void CompRepeat (void){  // ( then again -- )
    CompAgain();
    CompThen();
}
void CompPlusUntil (void){  // ( again -- )
    NeedSlot(20);
    uint32_t dest = PopNum();
    Implicit(opSKIPGE);
    Explicit(opJUMP, dest>>2);
}
void CompUntil (void){  // ( again -- )
    NeedSlot(20);
    uint32_t dest = PopNum();
    Implicit(opSKIPNZ);
    Explicit(opJUMP, dest>>2);
}

uint32_t tick_e(char *name) {
    uint32_t ht = WordFind(name);
    if (!ht) {
        printf("\nInternal name not found");
        tiffIOR = -21;
    }
    return FetchCell(ht-4) & 0xFFFFFF;
}
void compile(char *name) {
    Compile(tick_e(name));
}

// Other structures use the control stack
static uint32_t leaveList[16]; // private LEAVE list
int leaves = 0;                   // number of LEAVEs to resolve

void CompDo (void){  // ( -- 0 addr )
    NoExecute();  NewGroup();
    PushNum(0);                 // DO has no forward jump
    Implicit(opSWAP);
    Implicit(opCOM);
    Implicit(opOnePlus);
    Implicit(opPUSH);
    Implicit(opPUSH);           // push -end, begin
    CompBegin();
    leaves = 0;
}
void CompQDo (void){  // ( -- a s addr )
    NoExecute();
    compile("(?do)");
    CompAhead();                // skip to end of LOOP
    CompBegin();
    leaves = 0;
}
void CompLeave (void){
    NoExecute();
    compile("unloop");
    CompAhead();                // skip to end of LOOP
    leaveList[leaves] = PopNum();
    leaves++;
}
void CompLoop (void){   // ( addr slot  addr -- )
    NoExecute();
    compile("(loop)");
    CompAgain();                // resolve the DO
    while (leaves--) {          // rake the leaves
        PushNum(leaveList[leaves]);
        CompThen();
    }
    CompThen();
}
void CompI (void){
    NoExecute();
    Implicit(opRfetch);
}


void CompDefer (void){                  // compile a forward reference
    NewGroup();
    Explicit(opJUMP, 0x3FFFFFF);
}
void CompCount(uint32_t cp) {
    Literal(cp);
    Implicit(opCfetchPlus);
}
void CompType(uint32_t cp) {
    CompCount(cp);
    compile("type");
}

// Functions invoked after being found, from either xte or xtc.
// Positive means execute in the VM.
// Negative means execute in C.

// VMtest allows stepping. DBG FOO starts vmTEST at address FOO.
// ESC makes Execute pick up where it left off.
// If the PC has reached the last EXIT, Execute will time out.

uint32_t breakpoint = -1;
uint32_t DbgPC;                         // shared with accessvm.c

void Execute(uint32_t xt) {
    uint32_t i;
#ifdef VERBOSE
    printf(", Executing at %X", xt);
#endif // VERBOSE
    SetDbgReg(DbgPC);
    DbgGroup(opDUP, opPORT, opPUSH, opSKIP, opNOP); // Push current PC
    SetDbgReg(0xDEADC0DC);
    DbgGroup(opDUP, opPORT, opPUSH, opSKIP, opNOP); // Push bogus return address
    SetDbgReg(xt);
    DbgGroup(opDUP, opPORT, opPUSH, opEXIT, opNOP); // Jump to code to run
    DbgPC = xt;
    for (i=1; i<RunLimit; i++) {
        if (DbgPC == breakpoint) {
            DbgPC = vmTEST();                       // invoke low level debugger
            if (!DbgPC) {                           // 0 quits early
                DbgGroup(opPOP, opDROP, opEXIT, opSKIP, opNOP); // restore PC
                return;
            }
            printf("Resuming at 0x%X ", DbgPC*4);
        }
        uint32_t ir = FetchCell(DbgPC);
#ifdef VERBOSE
        printf("\nStep %d: IR=%08X, PC=%X", i, ir, DbgPC);
#endif // VERBOSE
        DbgPC = 4 * VMstep(ir, 0);
#ifdef VERBOSE
        printf(" ==> PC=%X", DbgPC);
#endif // VERBOSE
        if ((DbgPC == 0xDEADC0DC) || (tiffIOR)) {          // Terminator or error found
            DbgGroup(opEXIT, opSKIP, opNOP, opNOP, opNOP); // restore PC
#ifdef VERBOSE
                printf("\nFinished after %d groups\n", i);
#endif // VERBOSE
            return;
        }
    }
    printf("\nHit the RunLimit in compile.c");
}

void tiffFUNC (int32_t n) {   /*EXPORT*/
    if (n & 0x800000) n |= 0xFF000000; // sign extend 24-bit n
	if (n<0) { // internal C function
#ifdef VERBOSE
        printf("xt=%X, ht=%X ", n, FetchCell(HEAD));
#endif
        uint32_t ht = FetchCell(HEAD);
        uint32_t w = FetchCell(ht-16);
		switch(~n) {
			case 0: PushNum (w);    break;
			case 1: Literal (w);    break;
			case 2: FakeIt  (w);    break;  // execute opcode
            case 3: Implicit(w);    break;  // compile implicit opcode
            case 4: tiffIOR = -14;  break;
            case 5: Immediate(w);   break;  // compile immediate opcode
            case 6: SkipOp(w);      break;  // compile skip opcode
            case 7: HardSkipOp(w);  break;  // compile skip opcode in slot 0
            case 8: FlushLit();  NewGroup();   break;  // skip to new instruction group
			case 9: PushNum (w);  FakeIt(opUP); break;     // execute user variable
			case 10: Literal (w);  Implicit(opUP); break;  // compile user variable
// Compile xt must be multiple of 8 so that clearing bit2 converts to a macro
            case 16: Compile     (FetchCell(ht-4) & 0xFFFFFF); break;  // compile call to xte
            case 20: CompileMacro(FetchCell(ht-4) & 0xFFFFFF); break;
            case 24: Execute     (FetchCell(ht-4) & 0xFFFFFF); break;
			default: break;
		}
	} else {
	    Execute(n); // execute in the VM
	}
}

static void AddImplicit(int opcode, char *name) {
    CommaH(opcode);
    CommaHeader(name, ~2, ~3, 0, 0);
}
static void AddExplicit(int opcode, char *name) {
    CommaH(opcode);
    CommaHeader(name, ~4, ~5, 0, 0);
}
static void AddSkip(int opcode, char *name) {
    CommaH(opcode);
    CommaHeader(name, ~4, ~6, 0, 0);
}
static void AddHardSkip(int opcode, char *name) {
    CommaH(opcode);
    CommaHeader(name, ~4, ~7, 0, 0);
}
static void AddUserVar(int index, char *name) {
    CommaH(index*4);                    // user variable index
    CommaHeader(name, ~9, ~10, 0, 0);
}
void InitCompiler(void) {  /*EXPORT*/   // Initialize the compiler
    InitIR();
    memset(OpcodeCount, 0, sizeof(uint32_t)*64); // clear static opcode counters
    CommaHeader("|", ~4, ~8, 0, 0);     // skip to new opcode group
    AddImplicit(opNOP       , "nop");
    AddImplicit(opDUP       , "dup");
    AddImplicit(opADD       , "+");
    AddImplicit(opADDC      , "c+");
    AddImplicit(opRfetch    , "r@");
    AddImplicit(opAND       , "and");
    AddImplicit(opOVER      , "over");
    AddImplicit(opPOP       , "r>");
    AddImplicit(opXOR       , "xor");
    AddExplicit(opHost      , "host");
    AddImplicit(opTwoStar   , "2*");
    AddImplicit(opTwoStarC  , "2*c");
    AddImplicit(opCstorePlus, "c!+");
    AddImplicit(opCfetchPlus, "c@+");
    AddImplicit(opCfetchPlus, "count");
    AddImplicit(opCfetch    , "c@");
    AddImplicit(opWstorePlus, "w!+");
    AddImplicit(opWfetchPlus, "w@+");
    AddImplicit(opWfetch    , "w@");
    AddImplicit(opStorePlus , "!+");
    AddImplicit(opFetchPlus , "@+");
    AddImplicit(opFetch     , "@");
    AddImplicit(opUtwoDiv   , "u2/");
    AddImplicit(opREPTC     , "reptc");
    AddImplicit(opMiREPT    , "-rept");
    AddImplicit(opTwoDiv    , "2/");
    AddImplicit(opSP        , "sp");
    AddImplicit(opCOM       , "invert");
    AddImplicit(opSetRP     , "rp!");
    AddImplicit(opRP        , "rp");
    AddImplicit(opPORT      , "port");
    AddImplicit(opSetSP     , "sp!");
    AddImplicit(opUP        , "up");
    AddImplicit(opSetUP     , "up!");
    AddExplicit(opLitX      , "litx");
    AddExplicit(opHost      , "host");
    AddExplicit(opUSER      , "user");
    AddExplicit(opJUMP      , "jmp");
    AddExplicit(opLIT       , "lit");
    AddImplicit(opDROP      , "drop");
    AddExplicit(opCALL      , "call");
    AddImplicit(opOnePlus   , "1+");
    AddImplicit(opOnePlus   , "char+");
//    AddImplicit(opTwoPlus   , "2+");
    AddImplicit(opFourPlus  , "cell+");
    AddImplicit(opPUSH      , ">r");
    AddImplicit(opSWAP      , "swap");
    AddSkip    (opSKIP      , "no:");
    AddSkip    (opSKIPNC    , "ifc:");
    AddSkip    (opSKIPNZ    , "ifz:");
    AddSkip    (opSKIPGE    , "-if:");
    AddHardSkip(opSKIP      , "|no");
    AddHardSkip(opSKIPNC    , "|ifc");
    AddHardSkip(opSKIPNZ    , "|ifz");
    AddHardSkip(opSKIPGE    , "|-if");
    AddImplicit(opZeroEquals, "0=");
    AddImplicit(opZeroLess  , "0<");
    AddUserVar (0           , "status");
    AddUserVar (1           , "follower");
    AddUserVar (2           , "rp0");
    AddUserVar (3           , "sp0");
    AddUserVar (4           , "tos");
}
