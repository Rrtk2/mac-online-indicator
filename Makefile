.PHONY: run

run:
	xcodebuild build \
		-project "Online Indicator.xcodeproj" \
		-scheme "Online Indicator" \
		-configuration Debug \
		-derivedDataPath build \
	&& open "build/Build/Products/Debug/Online Indicator.app"
