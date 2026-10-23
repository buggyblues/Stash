.PHONY: build test test-headless run locales release
build:
	bash swift/Scripts/build-app.sh
test:
	cd swift && swift test
test-headless:
	cd swift && swift test --skip NativeRegressionTests
run:
	bash swift/Scripts/build-app.sh --qa
	open swift/build/Stash-QA.app
locales:
	python3 swift/Scripts/generate-locales.py
release:
	bash swift/Scripts/release.sh
