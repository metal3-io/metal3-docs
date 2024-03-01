package main

import (
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"reflect"
	"strings"

	"github.com/blang/semver"
	"sigs.k8s.io/kubebuilder/docs/book/utils/plugin"
)

type ReleaseTag struct{}

// SupportsOutput checks if the given plugin supports the given output format.
func (ReleaseTag) SupportsOutput(_ string) bool { return true }

// Process modifies the book in the input, which gets returned as the result of the plugin.
func (l ReleaseTag) Process(input *plugin.Input) error {
	return plugin.EachCommand(&input.Book, "releasetag", func(chapter *plugin.BookChapter, args string) (string, error) {
		parsedVersions := semver.Versions{}
		var repo, owner string
		var found bool

		markers := reflect.StructTag(strings.TrimSpace(args))

		if repo, found = markers.Lookup("repo"); !found {
			return "", fmt.Errorf("releasetag requires tag \"repo\" to be set")
		}

		if owner, found = markers.Lookup("owner"); !found {
			return "", fmt.Errorf("releasetag requires tag \"owner\" to be set")
		}

		response, err := http.Get("https://proxy.golang.org/github.com/" + owner + "/" + repo + "/@v/list")
		if err != nil {
			log.Fatalln(err)
		}

		body, err := io.ReadAll(response.Body)
		if err != nil {
			log.Fatalln(err)
		}

		for _, s := range strings.Split(string(body), "\n") {
			if strings.Contains(s, "-") {
				continue
			}
			parsedVersion, err := semver.ParseTolerant(s)
			if err != nil {
				// Discard releases with tags that are not a valid semantic versions
				continue
			}
			parsedVersions = append(parsedVersions, parsedVersion)
		}

		var picked semver.Version
		for i, tag := range parsedVersions {
			if tag.GT(picked) {
				picked = parsedVersions[i]
			}
		}

		return fmt.Sprintf(":v%s", picked), nil
	})
}

func main() {
	cfg := ReleaseTag{}
	if err := plugin.Run(cfg, os.Stdin, os.Stdout, os.Args[1:]...); err != nil {
		log.Fatal(err.Error())
	}
}
