SHELL := /bin/bash

PACKAGE ?= configuration-aws-identity-center
XRD_DIR := apis/identitycenters
COMPOSITION := $(XRD_DIR)/composition.yaml
DEFINITION := $(XRD_DIR)/definition.yaml
EXAMPLE_DEFAULT := examples/identitycenters/example-minimal.yaml
EXAMPLES := $(wildcard examples/identitycenters/*.yaml)

clean:
	rm -rf _output
	rm -rf .up

build:
	up project build

render: render-example

render-example:
	up composition render $(COMPOSITION) $(EXAMPLE_DEFAULT)

render-all:
	@for example in $(EXAMPLES); do \
		echo "Rendering $$example"; \
		up composition render $(COMPOSITION) $$example; \
	done

test:
	up test run tests/test-*

validate: validate-composition validate-examples

validate-composition:
	up composition render $(COMPOSITION) $(EXAMPLE_DEFAULT) --include-full-xr --quiet | crossplane beta validate $(XRD_DIR) --error-on-missing-schemas -

validate-examples:
	crossplane beta validate $(XRD_DIR) examples/identitycenters

publish:
	@if [ -z "$(tag)" ]; then echo "Error: tag is not set. Usage: make publish tag=<version>"; exit 1; fi
	up project build --push --tag $(tag)

generate-definitions:
	up xrd generate $(EXAMPLE_DEFAULT)

generate-function:
	up function generate --language=go-templating render $(COMPOSITION)

e2e:
	up test run tests/e2etest* --e2e
