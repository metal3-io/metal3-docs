FROM rust:1.69.0-slim@sha256:8b85a8a6bf7ed968e24bab2eae6f390d2c9c8dbed791d3547fef584000f48f9e
ARG MDBOOK_BIN_VERSION="0.4.15"
RUN cargo install mdbook --vers ${MDBOOK_BIN_VERSION}
RUN cp /usr/local/cargo/bin/mdbook /usr/bin/mdbook
WORKDIR /workdir
