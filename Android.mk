LOCAL_PATH := $(call my-dir)
ROOT_PATH := $(LOCAL_PATH)

# Lua static library (luasafe - andlua with bugfixes)
include $(ROOT_PATH)/luasafe/Android.mk

# luajava shared library (andluanewjava)
include $(ROOT_PATH)/andluanewjava/Android.mk
