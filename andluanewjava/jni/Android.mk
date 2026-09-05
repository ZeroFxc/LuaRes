LOCAL_PATH := $(call my-dir)

# === liblua 静态库 ===
include $(CLEAR_VARS)
LOCAL_MODULE := liblua
LOCAL_SRC_FILES := \
	../../andlua/lapi.c ../../andlua/lcode.c ../../andlua/lctype.c ../../andlua/ldebug.c \
	../../andlua/ldo.c ../../andlua/ldump.c ../../andlua/lfunc.c ../../andlua/lgc.c \
	../../andlua/llex.c ../../andlua/lmem.c ../../andlua/lobject.c ../../andlua/lopcodes.c \
	../../andlua/lparser.c ../../andlua/lstate.c ../../andlua/lstring.c ../../andlua/ltable.c \
	../../andlua/ltm.c ../../andlua/lundump.c ../../andlua/lvm.c ../../andlua/lzio.c \
	../../andlua/lauxlib.c ../../andlua/lbaselib.c ../../andlua/lbitlib.c ../../andlua/lcorolib.c \
	../../andlua/ldblib.c ../../andlua/liolib.c ../../andlua/lmathlib.c ../../andlua/loslib.c \
	../../andlua/lstrlib.c ../../andlua/ltablib.c ../../andlua/lutf8lib.c ../../andlua/loadlib.c \
	../../andlua/linit.c ../../andlua/lunsafe.c \
	../../luaclib/luac.c
LOCAL_C_INCLUDES := $(LOCAL_PATH)/../../andlua $(LOCAL_PATH)/../../luaclib
LOCAL_CFLAGS := -std=c99 -Dfseeko=fseek -Dftello=ftell -O2
include $(BUILD_STATIC_LIBRARY)

# === libluajava 动态库 ===
include $(CLEAR_VARS)
LOCAL_MODULE := luajava
LOCAL_SRC_FILES := luajava.c
LOCAL_C_INCLUDES := $(LOCAL_PATH)/../../andlua $(LOCAL_PATH)/../../luaclib
LOCAL_CFLAGS := -Wno-pointer-to-int-cast -Wno-int-to-pointer-cast -std=c99 -O2
LOCAL_LDLIBS := -lz -llog -ldl
LOCAL_STATIC_LIBRARIES := liblua
include $(BUILD_SHARED_LIBRARY)
