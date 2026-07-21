ARCHS = arm64
TARGET = iphone:clang:14.4:13.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FrezonMod
FrezonMod_FILES = Tweak.m WalletManager.m
FrezonMod_FRAMEWORKS = UIKit Foundation WebKit
FrezonMod_CFLAGS = -fobjc-arc

include $(THEOS)/makefiles/tweak.mk
