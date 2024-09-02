.PHONY: deps tidy-lint fmt all

GOLANGCI_LINTER_VERSION := 1.56.2

all: deps fmt tidy-lint
fmt: go-fmt terraform-fmt

export GOPROXY=${CI_GOPROXY}
export GOPRIVATE=gitlab.com/odeeo/*
export CGO_ENABLED=0


go-fmt:
	@echo "Checking formatting of go code..."
	@result=$$(gofmt -d -l -e tests/kubernetes/ 2>&1); \
		if [ "$$result" ]; then \
			echo "$$result"; \
			echo "gofmt failed!"; \
			exit 1; \
		fi

terraform-fmt:
	@echo "Checking formatting of terraform code..."
	@result=$$(terraform fmt -check -recursive modules/ examples/ 2>&1); \
		if [ "$$result" ]; then \
			echo "$$result"; \
			echo "terraform fmt failed!"; \
			exit 1; \
		fi

tidy-lint:
	@echo "Validate dependencies..."
	@go mod tidy
	@if ! git diff --quiet -- go.mod go.sum; then echo "Please check dependencies:"; git --no-pager diff; exit 1; fi

deps:
	@echo "Download dependencies"
	@go mod download
