LOCAL_PATH := $(call my-dir)
ROOT_PATH := $(LOCAL_PATH)

# Lua static library (andlua modified)
include $(ROOT_PATH)/andlua/Android.mk

# luajava shared library (androlua - (long,int) params, modified)
include $(ROOT_PATH)/andluanewjava/Android.mk
