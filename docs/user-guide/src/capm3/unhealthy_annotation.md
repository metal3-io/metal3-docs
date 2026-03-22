# Unhealthy Annotation

The `capi.metal3.io/unhealthy` annotation is used by
Cluster API Provider Metal³ (CAPM3) to mark **BareMetalHost** objects
that should not be selected for provisioning new `Metal3Machine` resources.

When this annotation is present, CAPM3 excludes the annotated host from
consideration when matching available hardware to new Machines.
This prevents the reuse of hosts that are known to be unhealthy or
have failed remediation attempts.

## Manual usage

Operators can manually mark a host as unhealthy by adding the following annotation
to a `BareMetalHost` object:

```yaml
metadata:
  annotations:
    capi.metal3.io/unhealthy: "true"
```

Removing the annotation re-enables the host for normal provisioning by CAPM3.

## Automatic application after remediation timeout

Starting from CAPM3 API version `v1alpha4` (available in previous release branches),
this annotation may also be **applied automatically** when remediation attempts
timeout and the node fails to recover.

During a remediation cycle managed by a `Metal3Remediation` resource, the following
parameters define retry and timeout behavior:

- `.spec.strategy.retryLimit` — the number of reboot retries permitted before the
  remediation is considered failed.
- `.spec.strategy.timeout` — the duration to wait between retries for the node to
  become healthy.

If the final timeout expires and the node remains unhealthy:

1. CAPM3 sets the `MachineOwnerRemediatedCondition=False` condition on the affected
   `Machine` to begin deletion of the unhealthy `Machine` and related remediation
   objects.
1. The corresponding `BareMetalHost` is automatically annotated with:

```yaml
   metadata:
     annotations:
       capi.metal3.io/unhealthy: "true"
```

This automatic annotation ensures that CAPM3 does not immediately attempt
to reuse the same physical host for another Machine after remediation failure.
The host remains excluded from new provisioning until an operator manually
removes the annotation after verifying and correcting the underlying issue.

Check the [Remediation](https://book.metal3.io/capm3/remediaton/) process
for more details.
