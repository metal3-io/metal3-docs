# bare-metal-style-guide

A trivial - but unfortunately common - challenge with Metal³ and
related projects is choosing the correct spelling of "bare metal" in
any given context. Is it "bare metal", or "baremetal", or
"bare-metal", or "Baremetal", or "Baremetal"? The answer is ... it
depends!

The goal of this document is to resolve this question and make it easy
for anyone to follow the agreed convention.

## 1. In prose, it is "bare metal"

Examples:

1. "We are implementing bare metal host management for Kubernetes"
1. "We manage bare metal hosts"

## 2. For names, it is "Bare Metal"

Examples:

1. "The Bare Metal Operator"
1. "The Bare Metal Actuator"

## 3. For lower-cased technical names, it is "baremetal"

Examples:

1. "The Bare Metal Operator is in the baremetal-operator repo"
1. "The Bare Metal Actuator is in the cluster-api-provider-baremetal repo"
1. "The 'baremetal' driver implements support for bare metal servers"

## 4. For camel-cased identifiers in code, it is "BareMetal"

Examples:

1. "The BareMetalHost resource"

## 5. It is never "bare-metal"
