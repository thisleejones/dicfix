# Makefile for dictfix

# Variables
PROJECT_NAME = dicfix
SCHEME = dicfix
PROJECT = $(PROJECT_NAME).xcodeproj
CONFIGURATION = Debug
BUILD_DIR = build
INSTALL_DIR ?= /Applications
EXECUTABLE_PATH = "$(BUILD_DIR)/Build/Products/$(CONFIGURATION)/$(PROJECT_NAME).app/Contents/MacOS/$(PROJECT_NAME)"

.PHONY: all build clean run install lint test

all: build

build:
	@echo "Building $(PROJECT_NAME)..."
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
	@$(EXECUTABLE_PATH) $(ARGS)

install: build
	@echo "Installing $(PROJECT_NAME) to $(INSTALL_DIR)..."
	@cp -R "$(BUILD_DIR)/Build/Products/$(CONFIGURATION)/$(PROJECT_NAME).app" "$(INSTALL_DIR)/"

lint:
	@echo "Linting..."
	@swiftlint

test:
	@echo "Testing..."
	@xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) test