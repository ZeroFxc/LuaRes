/*
** vm_asm_ops.c - Opcode metadata table
** Each entry: name, standard opcode, operand format, handler template.
** Templates use placeholders: {A} {B} {C} {Bx} {sBx} {REG:x} {RK:x} {K:x} {JMP:x} {NEXT} {PC}
*/
#include "vm_asm.h"

static const VmOp op_table[] = {
    {"MOVE",     0,  FMT_ABC,  "{REG:{A}} = {REG:{B}}", NULL},
    {"LOADK",    1,  FMT_ABx,  "{REG:{A}} = {K:{Bx}}", NULL},
#if VM_ASM_DEBUG
    {"LOADKX",   2,  FMT_AB,   "local _nx=code[{PC}+1]; local _ax=(_nx[2] or 0)|((_nx[5] or 0)<<8); io.stderr:write('LOADKX pc='..{PC}..' a='..{A}..' nx_a='..(_nx[2] or 0)..' nx_bx='..(_nx[5] or 0)..' ax='.._ax..' #K='..#K..'\\n'); io.stderr:flush(); {REG:{A}}=K[_ax+1]; {NEXT}", NULL},
#else
    {"LOADKX",   2,  FMT_AB,   "local _nx=code[{PC}+1]; {REG:{A}}=K[(_nx[2] or 0)|((_nx[5] or 0)<<8)+1]; {NEXT}", NULL},
#endif
    {"LOADBOOL", 3,  FMT_ABC,  "{REG:{A}} = ({B}~=0); if {C}~=0 then {NEXT} end", NULL},
    {"LOADNIL",  4,  FMT_AB,   "for _i={A},{A}+{B} do {REG:_i}=nil end", NULL},
    {"GETUPVAL", 5,  FMT_AB,   "{REG:{A}} = getuv({B})", NULL},
    {"GETTABUP", 6,  FMT_ABC,  "{REG:{A}} = getuv({B})[{RK:{C}}]", NULL},
    {"GETTABLE", 7,  FMT_ABC,  "{REG:{A}} = {REG:{B}}[{RK:{C}}]", NULL},
    {"SETTABUP", 8,  FMT_ABC,  "getuv({A})[{RK:{B}}] = {RK:{C}}", NULL},
    {"SETUPVAL", 9,  FMT_AB,   "setuv({B}, {REG:{A}})", NULL},
    {"SETTABLE", 10, FMT_ABC,  "{REG:{A}}[{RK:{B}}] = {RK:{C}}", NULL},
    {"NEWTABLE", 11, FMT_ABC,  "{REG:{A}} = {}", NULL},
    {"SELF",     12, FMT_ABC,  "{REG:{A}+1}={REG:{B}}; {REG:{A}}={REG:{B}}[{RK:{C}}]", NULL},
    {"ADD",      13, FMT_ABC,  "{REG:{A}} = {RK:{B}} + {RK:{C}}", NULL},
    {"SUB",      14, FMT_ABC,  "{REG:{A}} = {RK:{B}} - {RK:{C}}", NULL},
    {"MUL",      15, FMT_ABC,  "{REG:{A}} = {RK:{B}} * {RK:{C}}", NULL},
    {"MOD",      16, FMT_ABC,  "{REG:{A}} = {RK:{B}} % {RK:{C}}", NULL},
    {"POW",      17, FMT_ABC,  "{REG:{A}} = {RK:{B}} ^ {RK:{C}}", NULL},
    {"DIV",      18, FMT_ABC,  "{REG:{A}} = {RK:{B}} / {RK:{C}}", NULL},
    {"IDIV",     19, FMT_ABC,  "{REG:{A}} = {RK:{B}} // {RK:{C}}", "{REG:{A}} = _idiv({RK:{B}}, {RK:{C}})"},
#if VM_ASM_DEBUG
    {"BAND",     20, FMT_ABC,  "local _b={RK:{B}}; local _c={RK:{C}}; if _b==nil or _c==nil then io.stderr:write('BITOP nil pc='..{PC}..' op=20 a='..{A}..' b='..{B}..' c='..{C}..' Rb='..tostring(_b)..' Rc='..tostring(_c)..'\\n'); io.stderr:flush() end; {REG:{A}} = _b & _c", "{REG:{A}} = _band({RK:{B}}, {RK:{C}})"},
#else
    {"BAND",     20, FMT_ABC,  "{REG:{A}} = {RK:{B}} & {RK:{C}}", "{REG:{A}} = _band({RK:{B}}, {RK:{C}})"},
#endif
    {"BOR",      21, FMT_ABC,  "local _b={RK:{B}}; local _c={RK:{C}}; if _b==nil or _c==nil then io.stderr:write('BITOP nil pc='..{PC}..' op=21 a='..{A}..' b='..{B}..' c='..{C}..' Rb='..tostring(_b)..' Rc='..tostring(_c)..'\\n'); io.stderr:flush() end; {REG:{A}} = _b | _c", "{REG:{A}} = _bor({RK:{B}}, {RK:{C}})"},
#if VM_ASM_DEBUG
    {"BXOR",     22, FMT_ABC,  "local _b={RK:{B}}; local _c={RK:{C}}; if _b==nil or _c==nil then io.stderr:write('BITOP nil pc='..{PC}..' op=22 a='..{A}..' b='..{B}..' c='..{C}..' Rb='..tostring(_b)..' Rc='..tostring(_c)..'\\n'); io.stderr:flush() end; {REG:{A}} = _b ~ _c", "{REG:{A}} = _bxor({RK:{B}}, {RK:{C}})"},
#else
    {"BXOR",     22, FMT_ABC,  "{REG:{A}} = {RK:{B}} ~ {RK:{C}}", "{REG:{A}} = _bxor({RK:{B}}, {RK:{C}})"},
#endif
    {"SHL",      23, FMT_ABC,  "local _b={RK:{B}}; local _c={RK:{C}}; if _b==nil or _c==nil then io.stderr:write('BITOP nil pc='..{PC}..' op=23 a='..{A}..' b='..{B}..' c='..{C}..' Rb='..tostring(_b)..' Rc='..tostring(_c)..'\\n'); io.stderr:flush() end; {REG:{A}} = _b << _c", "{REG:{A}} = _shl({RK:{B}}, {RK:{C}})"},
    {"SHR",      24, FMT_ABC,  "local _b={RK:{B}}; local _c={RK:{C}}; if _b==nil or _c==nil then io.stderr:write('BITOP nil pc='..{PC}..' op=24 a='..{A}..' b='..{B}..' c='..{C}..' Rb='..tostring(_b)..' Rc='..tostring(_c)..'\\n'); io.stderr:flush() end; {REG:{A}} = _b >> _c", "{REG:{A}} = _shr({RK:{B}}, {RK:{C}})"},
    {"UNM",      25, FMT_AB,   "{REG:{A}} = -{REG:{B}}", NULL},
    {"BNOT",     26, FMT_AB,   "{REG:{A}} = ~{REG:{B}}", "{REG:{A}} = _bnot({REG:{B}})"},
    {"NOT",      27, FMT_AB,   "{REG:{A}} = not {REG:{B}}", NULL},
    {"LEN",      28, FMT_AB,   "{REG:{A}} = #{REG:{B}}", NULL},
    {"CONCAT",   29, FMT_ABC,  "local _s={}; for _i={B},{C} do _s[#_s+1]=tostring({REG:_i}) end; {REG:{A}}=table.concat(_s)", NULL},
    {"JMP",      30, FMT_AsBx, "if {A}~=0 then closeuv({A}-1) end; {JMP:{sBx}}", NULL},
    {"EQ",       31, FMT_ABC,  "if ({RK:{B}}=={RK:{C}}) ~= ({A}~=0) then {NEXT} end", NULL},
    {"LT",       32, FMT_ABC,  "if ({RK:{B}}<{RK:{C}}) ~= ({A}~=0) then {NEXT} end", NULL},
    {"LE",       33, FMT_ABC,  "if ({RK:{B}}<={RK:{C}}) ~= ({A}~=0) then {NEXT} end", NULL},
    {"TEST",     34, FMT_ABC,  "local _v={REG:{A}}; local _f=(_v==nil or _v==false); if ({C}~=0 and _f) or ({C}==0 and not _f) then {NEXT} end", NULL},
    {"TESTSET",  35, FMT_ABC,  "local _v={REG:{B}}; local _f=(_v==nil or _v==false); if ({C}~=0 and _f) or ({C}==0 and not _f) then {REG:{A}}=_v else {NEXT} end", NULL},
    {"CALL",     36, FMT_ABC,  "docall({A},{B},{C})", NULL},
    {"TAILCALL", 37, FMT_ABC,  "return dotailcall({A},{B})", NULL},
    {"RETURN",   38, FMT_AB,   "return doreturn({A},{B})", NULL},
    {"FORLOOP",  39, FMT_AsBx, "{REG:{A}}={REG:{A}}+{REG:{A}+2}; if ({REG:{A}+2}>=0 and {REG:{A}}<={REG:{A}+1}) or ({REG:{A}+2}<0 and {REG:{A}}>={REG:{A}+1}) then {REG:{A}+3}={REG:{A}}; {JMP:{sBx}} end", NULL},
    {"FORPREP",  40, FMT_AsBx, "{REG:{A}}={REG:{A}}-{REG:{A}+2}; {JMP:{sBx}}", NULL},
    {"TFORCALL", 41, FMT_ABC,  "dotforcall({A},{C})", NULL},
    {"TFORLOOP", 42, FMT_AsBx, "if {REG:{A}+1}~=nil then {REG:{A}}={REG:{A}+1}; {JMP:{sBx}} end", NULL},
    {"SETLIST",  43, FMT_ABC,  "dosetlist({A},{B},{C})", NULL},
    {"CLOSURE",  44, FMT_ABx,  "{REG:{A}} = makeclosure({Bx})", NULL},
    {"VARARG",   45, FMT_AB,   "dovararg({A},{B})", NULL},
    {"EXTRAARG", 46, FMT_Ax,   NULL, NULL},
    /* andlua extensions - stubs */
    {"TBC",      47, FMT_AB,   NULL, NULL},
    {"NEWARRAY", 48, FMT_ABC,  "{REG:{A}} = {}", NULL},
    {"TFOREACH", 49, FMT_ABC,  NULL, NULL},
    {"SECTION",  50, FMT_ABC,  NULL, NULL},
    {"IS",       51, FMT_ABC,  "{REG:{A}} = (type({REG:{B}}) == {C})", NULL},
    {"TRY",      52, FMT_ABC,  NULL, NULL},
    {"TRYRETURN",53, FMT_AB,   "return doreturn({A},{B})", NULL},
};

#define OP_COUNT (sizeof(op_table)/sizeof(op_table[0]))

const VmOp *vm_op_table(int *count) {
    if (count) *count = (int)OP_COUNT;
    return op_table;
}
