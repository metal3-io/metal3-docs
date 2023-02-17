# User-guide structure

We use [mdbook](https://github.com/rust-lang/mdBook) project to build the user-guide.
All the content should be located within `docs/user-guide/src/` directory.

The structure of the book is based on the `SUMMARY.md` file.
`book.toml` is used as the configuration file for the mdbook.
Each GitHub project has its own directory to keep related documents.For example:

- `docs/user-guide/src/bmo` for Baremetal Operator related content
- `docs/user-guide/src/capm3` for Cluster-API-Provider-Metal3 related content
- `docs/user-guide/src/ironic` for Ironic related content
- `docs/user-guide/src/ipam` for Ip-address-manager related content

Similarly, we have the copy of the OWNERS file from each project, which gives reviewer and approver rights on the docs to the same maintainers of the project:

- `docs/user-guide/src/bmo/OWNERS`
- `docs/user-guide/src/capm3/OWNERS`
- `docs/user-guide/src/ironic/OWNERS`
- `docs/user-guide/src/ipam/OWNERS`

## Automatic build process

Netlify is configured to build the user-guide periodically from the current state of the main branch. As such, when there is a documentation change merged, at the latest it will be visible in the official user-guide the next day.

Whenever build is triggered, Netlify will fetch the mdbook binary first and run `make build` to build the content.
This generates HTML content to be published under `docs/user-guide/book` directory.
Last step, Netlify publishes the final content from `docs/user-guide/book`.
The final content is built on the fly by Netlify as such, we don't store it on GitHub.

## What's the URL of the current user-guide

[https://book.metal3.io/](https://book.metal3.io/)

## How to check book content when reviewing a GitHub patch

Netlify is configured to build the book from a pull request branch and it will be reported on the PR as `netlify/metal3-user-guide/deploy-preview`.
As such, it helps reviewers to review the patch not as the markdown only but also as the final user-guide.
Our Netlify configuration is in the [netlify.toml](https://github.com/metal3-io/metal3-docs/blob/main/netlify.toml).

## Mdbook maintenance

All the configurations of the mdbook, such as content path, version, from where to get the binary while building the user-guide is defined in the [Makefile](https://github.com/metal3-io/metal3-docs/blob/main/Makefile).

```sh
MDBOOK_BIN_VERSION ?= v0.4.15
SOURCE_PATH := docs/user-guide
CONTAINER_RUNTIME ?= sudo docker
IMAGE_NAME := quay.io/metal3-io/mdbook
IMAGE_TAG ?= latest
HOST_PORT ?= 3000
BIN_DIR := hack
MDBOOK_BIN := $(BIN_DIR)/mdbook
...
```

## How to preview changes locally

Before submitting document change, you can run the same mdbook binary to preview the book.

1. Install the mdbook by following official docs [here](https://rust-lang.github.io/mdBook/)

1. You can use serve command to preview the user-guide running at localhost:3000

    ```shell
    cd docs/user-guide/
    mdbook serve
    ```

You should have the user-guide available now at `localhost:3000`.
Also, the serve command watches the `src` directory for changes and rebuilds the user-guide for every change.
