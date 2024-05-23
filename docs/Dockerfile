ARG BUILD_IMAGE=docker.io/golang:1.21.9@sha256:7d0dcbe5807b1ad7272a598fbf9d7af15b5e2bed4fd6c4c2b5b3684df0b317dd
FROM $BUILD_IMAGE as builder
WORKDIR /workspace

# Run this with docker build --build_arg $(go env GOPROXY) to override the goproxy
ARG goproxy=https://proxy.golang.org
ENV GOPROXY=$goproxy

# Copy the Go Modules manifests
COPY hack/tools/go.mod go.mod
COPY hack/tools/go.sum go.sum

# Cache deps before building and copying source so that we don't need to re-download as much
# and so that source changes don't invalidate our downloaded layer
RUN go mod download

# Copy the sources
COPY hack/tools/releasetags/ releasetags/

# Build
ARG ARCH=amd64
RUN CGO_ENABLED=0 GOOS=linux GOARCH=${ARCH} \
  go build -tags=tools -a -ldflags '-extldflags "-static"' \
  -o mdbook-releasetags ./releasetags

FROM rust:1.78.0-slim@sha256:517c6272b328bc51c87e099ef4adfbc7ab4558af2d757e8d423c7c3f1cbbf9d5
ARG MDBOOK_VERSION="0.4.37"
RUN cargo install mdbook --vers ${MDBOOK_VERSION}
RUN cp /usr/local/cargo/bin/mdbook /usr/bin/mdbook
COPY --from=builder /workspace/mdbook-releasetags /usr/bin/mdbook-releasetags
WORKDIR /workdir
