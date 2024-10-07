SHELL:=/usr/bin/env bash

# nb. homebrew-releaser assumes the program name is == the repository name
BIN_NAME:=macos-ups-mqtt-connector
BIN_VERSION:=$(shell ./.version.sh)

default: help
.PHONY: help  # via https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
help: ## Print help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: all
all: clean build ## build for macOS (amd64, arm64)

.PHONY: bundle-install
bundle-install: ## run bundle install (for CocoaPods)
	bundle install

.PHONY: pod-install
pod-install: ## run pod install
	./vendor/bundle/ruby/3.3.0/bin/pod install

.PHONY: clean
clean: ## remove build files & outputs
	rm -rf build out

.PHONY: build
build: ## build (for release) to ./out
	sed -i .bak 's/program_version = @"<dev>"/program_version = @"${BIN_VERSION}"/g' './macos-ups-mqtt-connector-objc/main.m'
	mkdir -p ./out
	xcodebuild \
		ONLY_ACTIVE_ARCH=NO \
		-workspace macos-ups-mqtt-connector-objc.xcworkspace \
		-configuration Release \
		-scheme macos-ups-mqtt-connector-objc \
		-destination platform=macOS \
		-archivePath out/macos-ups-mqtt-connector-${BIN_VERSION} archive
	cp ./out/macos-ups-mqtt-connector-${BIN_VERSION}.xcarchive/Products/usr/local/bin/macos-ups-mqtt-connector ./out/macos-ups-mqtt-connector-${BIN_VERSION}
	sed -i .bak 's/program_version = @"${BIN_VERSION}"/program_version = @"<dev>"/g' './macos-ups-mqtt-connector-objc/main.m'
