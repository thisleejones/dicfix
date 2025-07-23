# Makefile for dictfix

# Variables
PROJECT_NAME = dicfix
SCHEME = dicfix
PROJECT = $(PROJECT_NAME).xcodeproj
CONFIGURATION ?= Debug
BUILD_DIR = build
INSTALL_DIR ?= /Applications
EXECUTABLE_PATH = "$(BUILD_DIR)/Build/Products/$(CONFIGURATION)/$(PROJECT_NAME).app/Contents/MacOS/$(PROJECT_NAME)"
TESTS ?=

.PHONY: all build clean run install lint test release generate

all: build

generate:
	@if ! command -v tuist &> /dev/null; then \
		echo "Error: tuist is not installed. Please install it to continue."; \
		echo "See: https://tuist.io"; \
		exit 1; \
	fi
	@echo "Generating Xcode project with Tuist..."
	@tuist generate --no-open

build: generate


build:
	@echo "Building $(PROJECT_NAME) with $(CONFIGURATION) configuration..."
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -derivedDataPath $(BUILD_DIR) build

clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD_DIR)
	@rm -rf CompilationCache.noindex
	@rm -rf ModuleCache.noindex
	@rm -rf SDKStatCaches.noindex
	@rm -rf Index.noindex
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) clean

run: build
	@echo "Running $(PROJECT_NAME)..."
	@OS_ACTIVITY_MODE=disable $(EXECUTABLE_PATH) $(ARGS)

install: build
	@echo "Installing $(PROJECT_NAME) to $(INSTALL_DIR)..."
	@cp -R "$(BUILD_DIR)/Build/Products/$(CONFIGURATION)/$(PROJECT_NAME).app" "$(INSTALL_DIR)/"

release:
	@echo "Building release version of $(PROJECT_NAME)..."
	@$(MAKE) build CONFIGURATION=Release

lint:
	@echo "Linting..."
	@swiftlint

test: generate
	@echo "Testing..."
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) \
	$(foreach T,$(TESTS),-only-testing:$(T)) test
