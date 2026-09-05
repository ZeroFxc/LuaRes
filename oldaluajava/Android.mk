LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)

LOCAL_MODULE := luajava
LOCAL_SRC_FILES := luajava.c
LOCAL_C_INCLUDES := $(LOCAL_PATH) $(LOCAL_PATH)/../lua
LOCAL_CFLAGS := -std=c99 -Wno-pointer-to-int-cast -Wno-int-to-pointer-cast
LOCAL_LDLIBS := -llog -ldl -lz
LOCAL_STATIC_LIBRARIES := liblua

include $(BUILD_SHARED_LIBRARY)
