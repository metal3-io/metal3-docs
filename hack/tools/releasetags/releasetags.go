package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"reflect"
	"strings"

	"sigs.k8s.io/kubebuilder/docs/book/utils/plugin"
)

type ReleaseTag struct{}

// SupportsOutput checks if the given plugin supports the given output format.
func (ReleaseTag) SupportsOutput(_ string) bool { return true }

// Process modifies the book in the input, which gets returned as the result of the plugin.
func (l ReleaseTag) Process(input *plugin.Input) error {
	return plugin.EachCommand(&input.Book, "releasetag", func(chapter *plugin.BookChapter, args string) (string, error) {
		var repo string
		var found bool

		tags := reflect.StructTag(strings.TrimSpace(args))

		if repo, found = tags.Lookup("repo"); !found {
			return "", fmt.Errorf("releasetag requires tag \"repo\" to be set")
		}

		// Replace the content of the chapter with a JSON object
		replacedContent := map[string]string{
			"content": fmt.Sprintf("REPLACED_CONTENT_%s", repo),
		}
		replacedContentJSON, err := json.Marshal(replacedContent)
		if err != nil {
			return "", err
		}

		return string(replacedContentJSON), nil
	})
}

func main() {
	cfg := ReleaseTag{}

	// Read input from os.Stdin
	input, err := io.ReadAll(os.Stdin)
	if err != nil {
		log.Fatal(err)
	}

	// Write input to input.log
	err = os.WriteFile("input.log", input, 0644)
	if err != nil {
		log.Fatal(err)
	}

	// Create a bytes buffer to capture the output
	var output bytes.Buffer

	// Run the preprocessor
	if err := plugin.Run(cfg, bytes.NewReader(input), &output, os.Args[1:]...); err != nil {
		log.Fatal(err.Error())
	}

	// Write output to output.log
	err = os.WriteFile("output.log", output.Bytes(), 0644)
	if err != nil {
		log.Fatal(err)
	}
}
