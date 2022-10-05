# Waiting for BMHs to be available again

Sometimes the BMHs get stuck while deprovisioning.

```text
RETRYING: Wait until "2" bmhs become available again. 147/150
RETRYING: Wait until "2" bmhs become available again. 148/150
RETRYING: Wait until "2" bmhs become available again. 149/150
RETRYING: Wait until "2" bmhs become available again. 150/150
```

When this happens, the following can be seen in the BMO logs:

```text
{"level":"info","ts":1664171732.2929034,"logger":"controllers.BareMetalHost","msg":"start","baremetalhost":"metal3/eselda13u31s05"}
{"level":"info","ts":1664171732.3624265,"logger":"controllers.BareMetalHost","msg":"Retrying registration","baremetalhost":"metal3/eselda13u31s05","provisioningState":"provisioned"}
{"level":"info","ts":1664171732.3624785,"logger":"controllers.BareMetalHost","msg":"registering and validating access to management controller","baremetalhost":"metal3/eselda13u31s05","provisioningState":"provisioned","credentials":{"credentials":{"name":"bml-ilo-login-secret-05","namespace":"metal3"},"credentialsVersion":"9674"}}
{"level":"info","ts":1664171732.4302292,"logger":"provisioner.ironic","msg":"updating node settings in ironic","host":"metal3~eselda13u31s05"}
{"level":"info","ts":1664171732.5427444,"logger":"provisioner.ironic","msg":"could not update node settings in ironic, busy","host":"metal3~eselda13u31s05"}
{"level":"info","ts":1664171732.5427907,"logger":"controllers.BareMetalHost","msg":"host not ready","baremetalhost":"metal3/eselda13u31s05","provisioningState":"provisioned","wait":10}
{"level":"info","ts":1664171732.542827,"logger":"controllers.BareMetalHost","msg":"done","baremetalhost":"metal3/eselda13u31s05","provisioningState":"provisioned","requeue":true,"after":10}
```

And in Ironic we see this:

```text
2022-09-26 05:55:32.499 1 DEBUG ironic.conductor.manager [None req-97e7cdfd-1309-4a01-a42d-a503e221e900 - - - - - -] RPC update_node called for node 67b0163f-faf6-48e3-b5bf-946f37cb48d8. update_node /usr/lib/python3.9/site-packages/ironic/conductor/manager.py:193
2022-09-26 05:55:32.507 1 DEBUG ironic.conductor.task_manager [None req-97e7cdfd-1309-4a01-a42d-a503e221e900 - - - - - -] Attempting to get exclusive lock on node 67b0163f-faf6-48e3-b5bf-946f37cb48d8 (for node update) __init__ /usr/lib/python3.9/site-packages/ironic/conductor/task_manager.py:235
2022-09-26 05:55:32.516 1 DEBUG ironic.conductor.task_manager [None req-97e7cdfd-1309-4a01-a42d-a503e221e900 - - - - - -] Node 67b0163f-faf6-48e3-b5bf-946f37cb48d8 successfully reserved for node update (took 0.01 seconds) reserve_node /usr/lib/python3.9/site-packages/ironic/conductor/task_manager.py:352
2022-09-26 05:55:32.531 1 DEBUG ironic.conductor.task_manager [None req-97e7cdfd-1309-4a01-a42d-a503e221e900 - - - - - -] Successfully released exclusive lock for node update on node 67b0163f-faf6-48e3-b5bf-946f37cb48d8 (lock was held 0.01 sec) release_resources /usr/lib/python3.9/site-packages/ironic/conductor/task_manager.py:448
2022-09-26 05:55:32.534 1 DEBUG ironic.api.method [None req-97e7cdfd-1309-4a01-a42d-a503e221e900 - - - - - -] Client-side error: Node 67b0163f-faf6-48e3-b5bf-946f37cb48d8 is associated with instance 66b3a20d-9c99-4d0b-8f91-5d8ce7bad6f5. format_exception /usr/lib/python3.9/site-packages/ironic/api/method.py:124
2022-09-26 05:55:32.536 1 INFO eventlet.wsgi.server [None req-97e7cdfd-1309-4a01-a42d-a503e221e900 - - - - - -] 172.17.0.11,127.0.0.1 "PATCH /v1/nodes/67b0163f-faf6-48e3-b5bf-946f37cb48d8 HTTP/1.1" status: 409  len: 531 time: 0.0919740
```

The relevant code in Ironic can be found [here](https://opendev.org/openstack/ironic/src/commit/eeeaa274cfc7ebee52beaed97571e2f87127f2dd/ironic/db/sqlalchemy/api.py#L2056).

Recreating (deleting) the Ironic Pod seems to help.

## Occurrence and logs

- 16.06.2022 [metal3_main_v1a5_integration_test_centos](https://artifactory.nordix.org/artifactory/metal3/jenkins-logs/waiting-bmh-metal3_main_v1a5_integration_test_centos-154.tgz)

- 15.06.2022 [metal3_main_v1a5_integration_test_centos](https://artifactory.nordix.org/artifactory/metal3/jenkins-logs/waiting-bmh-metal3_main_v1a5_integration_test_centos-152.tgz)
