.PHONY: build run app install clean

# Compile a debug build.
build:
	swift build

# Run straight from the terminal (handy during development).
run:
	swift run

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
