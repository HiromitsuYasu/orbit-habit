PROJECT = OrbitHabit.xcodeproj
SCHEME = OrbitHabit
DESTINATION = platform=iOS Simulator,name=iPhone 16 Pro,OS=latest

.PHONY: generate lint test verify

generate:
	xcodegen generate

lint:
	swiftlint lint --strict --config .swiftlint.yml

test:
	xcodebuild test \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		CODE_SIGNING_ALLOWED=NO

verify: generate lint test
