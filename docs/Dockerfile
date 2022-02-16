FROM rust:1-slim
ARG MDBOOK_BIN_VERSION="0.4.15"
RUN cargo install mdbook --vers ${MDBOOK_BIN_VERSION}
RUN cp /usr/local/cargo/bin/mdbook /usr/bin/mdbook
WORKDIR /workdir