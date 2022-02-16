FROM rust:1-slim
ARG MDBOOK_VERSION="latest"
RUN cargo install mdbook --vers ${MDBOOK_VERSION}
RUN cp /usr/local/cargo/bin/mdbook /usr/bin/mdbook
WORKDIR /workdir