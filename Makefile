TARGET := iphone:clang:latest:12.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = cgss-patcher

cgss-patcher_FILES = Tweak.x
cgss-patcher_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
