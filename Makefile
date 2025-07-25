# Makefile for dictfix

# Variables
PROJECT_NAME = dicfix
SCHEME = dicfix
PROJECT = $(PROJECT_NAME).xcodeproj
CONFIGURATION ?= Debug
BUILD_DIR = build
INSTALL_DIR ?= /Applications
EXECUTABLE_PATH = "$(BUILD_DIR)/$(CONFIGURATION)/$(PROJECT_NAME).app/Contents/MacOS/$(PROJECT_NAME)"
TESTS ?=

.PHONY: all build clean run install lint test test-xc release

all: build

build:
	@mkdir -p $(BUILD_DIR)
	@if ! command -v tuist &> /dev/null; then \
		echo "Error: tuist is not installed. Please install it to continue."; \
		echo "See: https://tuist.io"; \
		exit 1; \
	fi
	@echo "Building $(PROJECT_NAME) with $(CONFIGURATION) configuration..."
	@tuist build --generate --configuration $(CONFIGURATION) --build-output-path $(BUILD_DIR)

clean:
	@echo "Cleaning..."
	@tuist clean

run: build
	@echo "Running $(PROJECT_NAME)..."
	@OS_ACTIVITY_MODE=disable $(EXECUTABLE_PATH) $(ARGS)

install:
	@echo "Building release version for installation..."
	@$(MAKE) build CONFIGURATION=Release
	@echo "Installing $(PROJECT_NAME) to $(INSTALL_DIR)..."
	@cp -R "$(BUILD_DIR)/Release/$(PROJECT_NAME).app" "$(INSTALL_DIR)/"

release:
	@echo "Building release version of $(PROJECT_NAME)..."
	@$(MAKE) build CONFIGURATION=Release

lint:
	@echo "Linting..."
	@swiftlint

test:
	@echo "Testing..."
	@tuist test --clean --configuration $(CONFIGURATION)

test-xc:
	@echo "Testing..."
	@if command -v xcbeautify &> /dev/null; then \
		xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) \
		$(foreach T,$(TESTS),-only-testing:$(T)) test | xcbeautify --disable-logging; \
	else \
		xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) \
		$(foreach T,$(TESTS),-only-testing:$(T)) test; \
	fi
