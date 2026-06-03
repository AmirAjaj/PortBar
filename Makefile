.PHONY: build run test lint format app install clean

# Compile a debug build.
build:
	swift build

# Run straight from the terminal (handy during development).
run:
	swift run

# Run the test suite (works with full Xcode or Command Line Tools).
test:
	./Scripts/test.sh

# Check formatting without modifying files.
lint:
	swift format lint --recursive --strict Sources Tests

# Reformat the code in place.
format:
	swift format --in-place --recursive Sources Tests

# Assemble a release PortBar.app into dist/.
app:
	./Scripts/build-app.sh release

# Build the .app and copy it into ~/Applications.
install: app
	cp -R dist/PortBar.app "$$HOME/Applications/"
	@echo "Installed to ~/Applications/PortBar.app"

clean:
	swift package clean
	rm -rf .build dist
