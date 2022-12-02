# Nordix harbor 504 timeout

Sometimes we get a timeout when pulling images from the Nordix registry. Here is an example:

```text
sudo podman pull registry.nordix.org/quay-io-proxy/metal3-io/vbmc
Trying to pull registry.nordix.org/quay-io-proxy/metal3-io/vbmc:latest...
Error: initializing source docker://registry.nordix.org/quay-io-proxy/metal3-io/vbmc:latest:
reading manifest latest in registry.nordix.org/quay-io-proxy/metal3-io/vbmc: received unexpected HTTP status: 504 Gateway Time-out
```

## Occurrence & logs

- 29.06.2022: [metal3_main_v1b1_e2e_test_centos](https://artifactory.nordix.org/ui/native/metal3/jenkins-logs/registry-timeout-metal3_main_v1b1_e2e_test_centos-213.tgz)

- 28.06.2022:
   - [metal3_main_v1b1_integration_test_centos](https://artifactory.nordix.org/artifactory/metal3/jenkins-logs/registry-timeout-metal3_main_v1b1_integration_test_centos-190.tgz)
   - [metal3_main_v1a5_integration_test_centos](https://artifactory.nordix.org/artifactory/metal3/jenkins-logs/registry-timeout-metal3_main_v1a5_integration_test_centos-167.tgz)
