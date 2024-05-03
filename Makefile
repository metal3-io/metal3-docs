MDBOOK_BIN_VERSION ?= v0.4.15
SOURCE_PATH := docs/user-guide
CONTAINER_RUNTIME ?= sudo docker
IMAGE_NAME := quay.io/metal3-io/mdbook
IMAGE_TAG ?= latest
HOST_PORT ?= 3000
BIN_DIR := hack
MDBOOK_BIN := $(BIN_DIR)/mdbook
MDBOOK_RELEASE_URL := https://github.com/rust-lang/mdBook/releases/download/$(MDBOOK_BIN_VERSION)/mdbook-$(MDBOOK_BIN_VERSION)-x86_64-unknown-linux-gnu.tar.gz

## ------------------------------------
## Documentation tooling for Netlify
## ------------------------------------

# This binary is used by Netlify. Because,
# Netlify build image doesn't support docker/podman.

$(MDBOOK_BIN): # Download the binary
	curl -L $(MDBOOK_RELEASE_URL) | tar xvz -C $(BIN_DIR)

.PHONY: netlify-build
netlify-build: $(MDBOOK_BIN) # Build the user guide
	$(MDBOOK_BIN) build $(SOURCE_PATH)


## ------------------------------------
## Documentation tooling for local dev
## ------------------------------------

.PHONY: build
build: # Build the user guide
	$(CONTAINER_RUNTIME) run \
	--rm -it --name metal3 \
	-v "$$(pwd):/workdir" \
	$(IMAGE_NAME):$(IMAGE_TAG) \
	mdbook build $(SOURCE_PATH)

.PHONY: serve
serve: # Serve the user-guide on localhost:3000 (by default)
	$(CONTAINER_RUNTIME) run \
	--rm -it --init --name metal3 \
	-v "$$(pwd):/workdir" \
	-p $(HOST_PORT):3000 \
	$(IMAGE_NAME):$(IMAGE_TAG) \
	mdbook serve --open $(SOURCE_PATH) -p 3000 -n 0.0.0.0

.PHONY: clean
clean: # Clean mdbook generated content
	$(CONTAINER_RUNTIME) run \
	--rm -it --name metal3 \
	-v "$$(pwd):/workdir" \
	$(IMAGE_NAME):$(IMAGE_TAG) \
	mdbook clean $(SOURCE_PATH)
