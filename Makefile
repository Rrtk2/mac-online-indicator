PROJECT = Online Indicator.xcodeproj
SCHEME = Online Indicator
DERIVED_DATA = build
APP_NAME = Online Indicator
DEBUG_APP = $(DERIVED_DATA)/Build/Products/Debug/$(APP_NAME).app
RELEASE_APP = $(DERIVED_DATA)/Build/Products/Release/$(APP_NAME).app
INSTALL_PATH = /Applications/$(APP_NAME).app

.PHONY: run build install

run:
	xcodebuild build \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Debug \
		-derivedDataPath $(DERIVED_DATA) \
	&& open "$(DEBUG_APP)"

build:
	xcodebuild build \
		-project "$(PROJECT)" \
		-scheme "$(SCHEME)" \
		-configuration Release \
		-derivedDataPath $(DERIVED_DATA)

install: build
	rm -rf "$(INSTALL_PATH)"
	cp -R "$(RELEASE_APP)" "$(INSTALL_PATH)"
	xattr -dr com.apple.quarantine "$(INSTALL_PATH)" 2>/dev/null || true
