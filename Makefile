BUILD_TS := $(shell date -Iseconds --utc)
COMMIT_SHA := $(shell git rev-parse HEAD)
VERSION := $(shell git describe --abbrev=0 --tags || echo "latest")
OS ?= linux

export CGO_ENABLED=0
export GOOS=$(OS)
export GO111MODULE=on

binary := $(if $(filter-out windows,$(OS)),kafkactl,kafkactl.exe)

module=$(shell go list -m)
ld_flags := "-X $(module)/cmd.Version=$(VERSION) -X $(module)/cmd.GitCommit=$(COMMIT_SHA) -X $(module)/cmd.BuildTime=$(BUILD_TS)"

FILES    := $(shell find . -name '*.go' -type f -not -name '*.pb.go' -not -name '*_generated.go' -not -name '*_test.go')
TESTS    := $(shell find . -name '*.go' -type f -not -name '*.pb.go' -not -name '*_generated.go' -name '*_test.go')

.DEFAULT_GOAL := all
.PHONY: all
all: fmt lint cve-check test build docs

fmt:
	gofmt -s -l -w $(FILES) $(TESTS)
	goimports -l -w $(FILES) $(TESTS)

.PHONY: update-dependencies
update-dependencies: # update dependencies to latest MINOR.PATCH
	go get -t -u ./...

lint:
	golangci-lint run

.PHONY: cve-check
cve-check:
	govulncheck ./...

.PHONY: test
test:
	rm -f test.log
	go test -v -short ./...

.PHONY: integration_test
integration_test:
	rm -f integration-test.log
	./docker/run-integration-tests.sh

.PHONY: build
build:
	go build -ldflags $(ld_flags) -o $(binary)

.PHONY: docs
docs: build
	touch /tmp/empty.yaml
	./kafkactl docs --directory docs --single-page --config-file=/tmp/empty.yaml

.PHONY: clean
clean:
	rm -f $(binary)
	go clean -testcache

# usage make version=2.5.0 release
#
# manually executing goreleaser:
# export GITHUB_TOKEN=xyz
# export AUR_SSH_PRIVATE_KEY=$(cat /path/to/id_aur)
# snapcraft login
# docker login
# goreleaser --clean (--skip-validate)
#
.PHONY: release
release:
	current_date=`date "+%Y-%m-%d"`; eval "sed -i 's/## \[Unreleased\].*/## [Unreleased]\n\n## $$version - $$current_date/g' CHANGELOG.md"
	git add "CHANGELOG.md"
	git commit -m "releases $(version)"
	git tag -a v$(version) -m "release v$(version)"
	git push origin
	git push origin v$(version)
