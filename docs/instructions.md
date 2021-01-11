# Metal³ user-guide instructions

We are using [Mdbook](https://github.com/rust-lang/mdBook) to build the
Metal³ user-guide. Below you will find step-by-step instructions on how
to test your changes.

## User-guide structure

Below is the concatenated file structure for the Metal³ user-guide.

```shell
├── book.toml
├── src
│   ├── images
│   │   └── metal3-color.svg
│   ├── introduction.md
│   ├── project-overview.md
│   └── SUMMARY.md
└── theme
    └── favicon.svg
```

### src

Apart from the actual content/files, `src` folder stores SUMMARY.md which
is consumed by the Mdbook, and defines the content structure.

### book.toml

All parameters and configurations of the user-guide is done via book.toml.
These include output parameters, redirects, metadata such as title,
description, authors, language, etc. More information on that can be found
[here](https://rust-lang.github.io/mdBook/format/config.html).

### SUMMARY.md

This is a context of the user-guide and defines the exact structure.
Based on any order of documents given in the STRUCTURE.md, mdbook will
try to fetch those documents and parse them out.

## Preview your changes locally

1. Download Mdbook binary. This will save the binary in /hack folder.

    ```bash
    $ make bin
    ```

1. Build the user-guide.

    ```bash
    $ make build
    ```

1. Preview the book built. This will open the user-guide in your browser.
    You can keep running `make watch` and continue making doc changes.
    Mdbook will detect and render the local changes automatically. Refresh
    the browser page to see the final changes.

    ```bash
    $ make watch
    ```

1. Once you have finished local preview, clean Mdbook auto-generated
    content from docs/user-guide/book path.

    ```bash
    $ make clean
    ```