# Download Calico manifests connection failure

Sometimes downloading the calico manifests fail with this error:

```text
TASK [v1aX_integration_test : Download Calico v3.21.x manifests] ***************
task path: /home/****/tested_repo/vm-setup/roles/v1aX_integration_test/tasks/verify.yml:22
fatal: [localhost]: FAILED! => {"changed": false, "dest": "/tmp/", "elapsed": 10, "gid": 0, "group": "root", "mode": "01777", "msg":
"Connection failure: The read operation timed out", "owner": "root", "size": 4096, "state": "directory", "uid": 0, "url": https://docs.projectcalico.org/archive/v3.21/manifests/calico.yaml}
```

## Occurrence & logs

- 28.06.2022 [metal3_main_feature_tests_ubuntu](https://artifactory.nordix.org/ui/native/metal3/jenkins-logs/calico-manifests-metal3_main_feature_tests_ubuntu-76.tgz)
