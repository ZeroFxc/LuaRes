LOCAL_PATH := $(call my-dir)

include $(CLEAR_VARS)
LOCAL_MODULE := luac
LOCAL_SRC_FILES := luac.c
LOCAL_C_INCLUDES := $(LOCAL_PATH)/../andlua
LOCAL_CFLAGS := -std=gnu99 -O2
include $(BUILD_STATIC_LIBRARY)
