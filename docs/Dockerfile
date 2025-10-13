ARG BUILD_IMAGE=docker.io/golang:1.25.3@sha256:6ea52a02734dd15e943286b048278da1e04eca196a564578d718c7720433dbbe
FROM $BUILD_IMAGE AS builder
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
  -o mdbook-releasetags ./releasetags && \
  go build -tags=tools -a -ldflags '-extldflags "-static"' \
  -o mdbook-embed sigs.k8s.io/cluster-api/hack/tools/mdbook/embed
ARG MDBOOK_RELEASE_URL="https://github.com/rust-lang/mdBook/releases/download/v0.4.52/mdbook-v0.4.52-x86_64-unknown-linux-gnu.tar.gz"
RUN curl -L "${MDBOOK_RELEASE_URL}" \
  | tar xvz -C /workspace

FROM netlify/build:noble
WORKDIR /workdir
COPY --from=builder /workspace/mdbook* /usr/bin/
