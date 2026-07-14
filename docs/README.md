# Metal³ user-guide instructions

We are using [Mdbook](https://github.com/rust-lang/mdBook) to build the
Metal³ user-guide. Below you will find step-by-step instructions on how
to test your changes.

## User-guide structure

Below is the concatenated file structure for the Metal³ user-guide.

```shell
├── book.toml
├── README.md
├── src
│   ├── bmo
│   │   └── OWNERS
│   ├── capm3
│   │   └── OWNERS
│   ├── images
│   │   └── metal3-color.svg
│   ├── introduction.md
│   ├── ipam
│   │   └── OWNERS
│   ├── ironic
│   │   └── OWNERS
│   └── SUMMARY.md
└── theme
    └── favicon.svg
```

### src

Apart from the actual content/files, `src` folder stores SUMMARY.md which
is consumed by the Mdbook, and defines the content structure.

### book.toml

All parameters and configurations of the user-guide is done via book.toml.
These include output parameters, redirects, metadata such as title,
description, authors, language, etc. More information on that can be found in
[mdBook configuration documentation](https://rust-lang.github.io/mdBook/format/config.html).

### SUMMARY.md

This is a context of the user-guide and defines the exact structure.
Based on any order of documents given in the STRUCTURE.md, mdbook will
try to fetch those documents and parse them out.

## Preview your changes locally

All the commands below are executed within mdbook container.

1. Build the user-guide.

    ```bash
    make build
    ```

1. Preview the user-guide built before pushing your changes. This will open the
    user-guide in your browser at `http://localhost:3000/`. Export `HOST_PORT`
    environment variable with desired port number to serve the user-guide on another
    port. You can keep running `make serve` and continue making doc changes. Mdbook
    will detect your changes, render them and refresh your browser page automatically.

    ```bash
    make serve
    ```

1. Clean Mdbook auto-generated content from docs/user-guide/book path once you
    have finished local preview.

    ```bash
    make clean
    ```

## Markers

There is a preprocessor written in Golang that resolves
`{{#releasetag owner:"metal3-io" repo:"cluster-api-provider-metal3"}}` type
markers as the latest version e.g. `:v1.6.1`.  It takes repository name and owner
as arguments. This preprocessor resolves the markers during netlify-build. Note:
preprocessor will return an error if the SUMMARY.md file has drafts (aka links
without a path) in the structure.
