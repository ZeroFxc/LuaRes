/*
** vm_asm_ops.c - Opcode metadata table
** Each entry: name, standard opcode, operand format, handler template.
** Templates use placeholders: {A} {B} {C} {Bx} {sBx} {REG:x} {RK:x} {K:x} {JMP:x} {NEXT} {PC}
*/
#include "vm_asm.h"

static const VmOp op_table[] = {
    {"MOVE",     0,  FMT_ABC,  "{REG:{A}} = {REG:{B}}"},
    {"LOADK",    1,  FMT_ABx,  "{REG:{A}} = {K:{Bx}}"},
    {"LOADKX",   2,  FMT_AB,   "{REG:{A}} = {K:EXTRA}"},
    {"LOADBOOL", 3,  FMT_ABC,  "{REG:{A}} = ({B}~=0); if {C}~=0 then {NEXT} end"},
    {"LOADNIL",  4,  FMT_AB,   "for _i={A},{A}+{B} do {REG:_i}=nil end"},
    {"GETUPVAL", 5,  FMT_AB,   "{REG:{A}} = getuv({B})"},
    {"GETTABUP", 6,  FMT_ABC,  "{REG:{A}} = getuv({B})[{RK:{C}}]"},
    {"GETTABLE", 7,  FMT_ABC,  "{REG:{A}} = {REG:{B}}[{RK:{C}}]"},
    {"SETTABUP", 8,  FMT_ABC,  "getuv({A})[{RK:{B}}] = {RK:{C}}"},
    {"SETUPVAL", 9,  FMT_AB,   "setuv({B}, {REG:{A}})"},
    {"SETTABLE", 10, FMT_ABC,  "{REG:{A}}[{RK:{B}}] = {RK:{C}}"},
    {"NEWTABLE", 11, FMT_ABC,  "{REG:{A}} = {}"},
    {"SELF",     12, FMT_ABC,  "{REG:{A}+1}={REG:{B}}; {REG:{A}}={REG:{B}}[{RK:{C}}]"},
    {"ADD",      13, FMT_ABC,  "{REG:{A}} = {RK:{B}} + {RK:{C}}"},
    {"SUB",      14, FMT_ABC,  "{REG:{A}} = {RK:{B}} - {RK:{C}}"},
    {"MUL",      15, FMT_ABC,  "{REG:{A}} = {RK:{B}} * {RK:{C}}"},
    {"MOD",      16, FMT_ABC,  "{REG:{A}} = {RK:{B}} % {RK:{C}}"},
    {"POW",      17, FMT_ABC,  "{REG:{A}} = {RK:{B}} ^ {RK:{C}}"},
    {"DIV",      18, FMT_ABC,  "{REG:{A}} = {RK:{B}} / {RK:{C}}"},
    {"IDIV",     19, FMT_ABC,  "{REG:{A}} = {RK:{B}} // {RK:{C}}"},
    {"BAND",     20, FMT_ABC,  "{REG:{A}} = {RK:{B}} & {RK:{C}}"},
    {"BOR",      21, FMT_ABC,  "{REG:{A}} = {RK:{B}} | {RK:{C}}"},
    {"BXOR",     22, FMT_ABC,  "{REG:{A}} = {RK:{B}} ~ {RK:{C}}"},
    {"SHL",      23, FMT_ABC,  "{REG:{A}} = {RK:{B}} << {RK:{C}}"},
    {"SHR",      24, FMT_ABC,  "{REG:{A}} = {RK:{B}} >> {RK:{C}}"},
    {"UNM",      25, FMT_AB,   "{REG:{A}} = -{REG:{B}}"},
    {"BNOT",     26, FMT_AB,   "{REG:{A}} = ~{REG:{B}}"},
    {"NOT",      27, FMT_AB,   "{REG:{A}} = not {REG:{B}}"},
    {"LEN",      28, FMT_AB,   "{REG:{A}} = #{REG:{B}}"},
    {"CONCAT",   29, FMT_ABC,  "local _s={}; for _i={B},{C} do _s[#_s+1]=tostring({REG:_i}) end; {REG:{A}}=table.concat(_s)"},
    {"JMP",      30, FMT_AsBx, "if {A}~=0 then closeuv({A}-1) end; {JMP:{sBx}}"},
    {"EQ",       31, FMT_ABC,  "if ({RK:{B}}=={RK:{C}}) ~= ({A}~=0) then {NEXT} end"},
    {"LT",       32, FMT_ABC,  "if ({RK:{B}}<{RK:{C}}) ~= ({A}~=0) then {NEXT} end"},
    {"LE",       33, FMT_ABC,  "if ({RK:{B}}<={RK:{C}}) ~= ({A}~=0) then {NEXT} end"},
    {"TEST",     34, FMT_ABC,  "local _v={REG:{A}}; local _f=(_v==nil or _v==false); if ({C}~=0 and _f) or ({C}==0 and not _f) then {NEXT} end"},
    {"TESTSET",  35, FMT_ABC,  "local _v={REG:{B}}; local _f=(_v==nil or _v==false); if ({C}~=0 and _f) or ({C}==0 and not _f) then {REG:{A}}=_v else {NEXT} end"},
    {"CALL",     36, FMT_ABC,  "docall({A},{B},{C})"},
    {"TAILCALL", 37, FMT_ABC,  "return dotailcall({A},{B})"},
    {"RETURN",   38, FMT_AB,   "return doreturn({A},{B})"},
    {"FORLOOP",  39, FMT_AsBx, "{REG:{A}}={REG:{A}}+{REG:{A}+2}; if ({REG:{A}+2}>=0 and {REG:{A}}<={REG:{A}+1}) or ({REG:{A}+2}<0 and {REG:{A}}>={REG:{A}+1}) then {REG:{A}+3}={REG:{A}}; {JMP:{sBx}} end"},
    {"FORPREP",  40, FMT_AsBx, "{REG:{A}}={REG:{A}}-{REG:{A}+2}; {JMP:{sBx}}"},
    {"TFORCALL", 41, FMT_ABC,  "dotforcall({A},{C})"},
    {"TFORLOOP", 42, FMT_AsBx, "if {REG:{A}+1}~=nil then {REG:{A}}={REG:{A}+1}; {JMP:{sBx}} end"},
    {"SETLIST",  43, FMT_ABC,  "dosetlist({A},{B},{C})"},
    {"CLOSURE",  44, FMT_ABx,  "{REG:{A}} = makeclosure({Bx})"},
    {"VARARG",   45, FMT_AB,   "dovararg({A},{B})"},
    {"EXTRAARG", 46, FMT_Ax,   NULL},
    /* andlua extensions - stubs */
    {"TBC",      47, FMT_AB,   NULL},
    {"NEWARRAY", 48, FMT_ABC,  "{REG:{A}} = {}"},
    {"TFOREACH", 49, FMT_ABC,  NULL},
    {"SECTION",  50, FMT_ABC,  NULL},
    {"IS",       51, FMT_ABC,  "{REG:{A}} = (type({REG:{B}}) == {C})"},
    {"TRY",      52, FMT_ABC,  NULL},
    {"TRYRETURN",53, FMT_AB,   "return doreturn({A},{B})"},
};

#define OP_COUNT (sizeof(op_table)/sizeof(op_table[0]))

const VmOp *vm_op_table(int *count) {
    if (count) *count = (int)OP_COUNT;
    return op_table;
}
