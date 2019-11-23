include $(THEOS)/makefiles/common.mk

TOOL_NAME = kbag
ARCHS = arm64
kbag_FILES = $(wildcard src/*.c) src/kbag.m
kbag_CFLAGS = -fobjc-arc -I. -Iinclude
kbag_FRAMEWORKS = IOKit
include $(THEOS_MAKE_PATH)/tool.mk
