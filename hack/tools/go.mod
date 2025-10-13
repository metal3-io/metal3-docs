module metal3-io/metal3-docs/hack/tools

go 1.24.0

require (
	github.com/blang/semver v3.5.1+incompatible
	sigs.k8s.io/kubebuilder/docs/book/utils v0.0.0-20240216033807-8afeb403549f
)

require sigs.k8s.io/cluster-api/hack/tools v0.0.0-20251020054008-0978f70c29b1 // indirect

tool sigs.k8s.io/cluster-api/hack/tools/mdbook/embed
