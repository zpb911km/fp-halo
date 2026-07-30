APP_ID = org.zpb.halo
PKG = $(APP_ID).plasmoid

all: build

build:
	cd src && zip -r ../$(PKG) . -x '.git/*' -x '*~'

install: build
	kpackagetool5 --type Plasma/Applet --install $(PKG) 2>/dev/null || \
	kpackagetool5 --type Plasma/Applet --upgrade $(PKG)

remove:
	kpackagetool5 --type Plasma/Applet --remove $(APP_ID) 2>/dev/null || true

reinstall: remove install

run:
	plasmoidviewer -a $(APP_ID)

.PHONY: all build install remove reinstall run
