BIN_DIR := hack
MDBOOK_BIN := $(BIN_DIR)/mdbook
MDBOOK_VERSION := v0.4.3
MDBOOK_RELEASE_URL := https://github.com/rust-lang/mdBook/releases/download/$(MDBOOK_VERSION)/mdbook-$(MDBOOK_VERSION)-x86_64-unknown-linux-gnu.tar.gz
SOURCE_PATH := docs/user-guide

## ----------------------
## Documentation tooling
## ----------------------

$(MDBOOK_BIN):
	curl -L $(MDBOOK_RELEASE_URL) | tar xvz -C $(BIN_DIR)

.PHONY: serve
serve: $(MDBOOK_BIN)
	$(MDBOOK_BIN) serve --open $(SOURCE_PATH)

.PHONY: build
build: $(MDBOOK_BIN)
	$(MDBOOK_BIN) build $(SOURCE_PATH)

.PHONY: watch
watch: $(MDBOOK_BIN)
	$(MDBOOK_BIN) watch --open $(SOURCE_PATH)

.PHONY: clean
clean: $(MDBOOK_BIN)
	$(MDBOOK_BIN) clean $(SOURCE_PATH)