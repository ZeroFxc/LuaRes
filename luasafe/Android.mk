LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := liblua
LOCAL_SRC_FILES := \
	lapi.c lcode.c lctype.c ldebug.c ldo.c ldump.c lfunc.c lgc.c llex.c \
	lmem.c lobject.c lopcodes.c lparser.c lstate.c lstring.c ltable.c \
	ltm.c lundump.c lvm.c lzio.c \
	lauxlib.c lbaselib.c lbitlib.c lcorolib.c ldblib.c liolib.c \
	lmathlib.c loslib.c lstrlib.c ltablib.c lutf8lib.c loadlib.c linit.c \
	lunsafe.c \
	luacapi_log.c luacapi_log_lua.c

# luaclib 混淆模块库（与 build_wasm.bat 同一套源码集，排除 wasm_entry.c / vm_asm.c / test_asm.c）
LUACLIB_SRC := $(filter-out %/wasm_entry.c %/vm_asm.c, $(wildcard $(LOCAL_PATH)/../luaclib/*.c))
VMASM_SRC   := $(filter-out %/test_asm.c, $(wildcard $(LOCAL_PATH)/../luaclib/vm_asm/*.c))
LUACLIB_SRC := $(patsubst $(LOCAL_PATH)/%,%,$(LUACLIB_SRC))
VMASM_SRC   := $(patsubst $(LOCAL_PATH)/%,%,$(VMASM_SRC))
LOCAL_SRC_FILES += $(LUACLIB_SRC) $(VMASM_SRC)

LOCAL_C_INCLUDES := $(LOCAL_PATH) $(LOCAL_PATH)/../luaclib $(LOCAL_PATH)/../luaclib/vm_asm
LOCAL_CFLAGS := -std=gnu99 -Dfseeko=fseek -Dftello=ftell \
	-DLUA_COMPAT_5_2 -DVM_EMBED_NO_MAIN

include $(BUILD_STATIC_LIBRARY)
