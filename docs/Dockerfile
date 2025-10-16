ARG BUILD_IMAGE=docker.io/golang:1.21.9@sha256:7d0dcbe5807b1ad7272a598fbf9d7af15b5e2bed4fd6c4c2b5b3684df0b317dd
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
  -o mdbook-releasetags ./releasetags
ARG MDBOOK_RELEASE_URL="https://github.com/rust-lang/mdBook/releases/download/v0.4.37/mdbook-v0.4.37-x86_64-unknown-linux-gnu.tar.gz"
RUN curl -L "${MDBOOK_RELEASE_URL}" \
  | tar xvz -C /workspace

FROM netlify/build:focal
WORKDIR /workdir
COPY --from=builder /workspace/mdbook-releasetags /workspace/mdbook /usr/bin/
