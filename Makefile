THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:latest:13.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = FrezonMod
FrezonMod_FILES = Tweak.xm WalletManager.m
FrezonMod_CFLAGS = -fobjc-arc -Wno-unused-variable
FrezonMod_FRAMEWORKS = UIKit Foundation WebKit
FrezonMod_RESOURCES = Resources

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "uicache -p /Applications/Subway\ Surfers.app"
	install.exec "killall SpringBoard"
