//==============================================================================
// compile.h: Header file for compile.c
//==============================================================================
#ifndef __COMPILE_H__
#define __COMPILE_H__
#include <stdint.h>
//#include "config.h"

void InitIR (void);                             // clear internal compiler state
void InitCompiler(void);               // load the dictionary with basic opcodes
void Literal (uint32_t n);                                  // compile a literal
void tiffFUNC (int32_t n);                                 // execute a function
void Semicolon (void);                                         // end definition
void NewGroup (void);                           // close out pending instruction
void tiffMACRO (void);                  // convert current definition to a macro
void tiffCALLONLY (void);                 // tag current definition as call-only
void tiffANON (void);                     // tag current definition as anonymous
void ListOpcodeCounts(void);             // list the static opcode count profile

#endif
