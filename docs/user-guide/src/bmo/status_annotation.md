# Status annotation

The status annotation is useful when you need to avoid inspection of a BareMetalHost.
This can happen if the status is already known, for example, when moving the BareMetalHost from one cluster to another.
By setting this annotation, the BareMetal Operator will take the status of the BareMetalHost directly from the annotation.

The annotation key is `baremetalhost.metal3.io/status` and the value is a JSON representation of the BareMetalHosts `status` field.
One simple way of extracting the status and turning it into an annotation is using kubectl like this:

```bash
# Save the status in json format to a file
kubectl get bmh <name-of-bmh> -o jsonpath="{.status}" > status.json
# Save the BMH and apply the status annotation to the saved BMH.
kubectl -n metal3 annotate bmh <name-of-bmh> \
  baremetalhost.metal3.io/status="$(cat status.json)" \
  --dry-run=client -o yaml > bmh.yaml
```

Note that the above example does not apply the annotation to the BareMetalHost directly since this is most likely not useful to apply it on one that already has a status.
Instead it saves the BareMetalHost *with the annotation applied* to a file `bmh.yaml`.
This file can then be applied in another cluster.
The status would be discarded at this point since the user is usually not allowed to set it, but the annotation is still there and would be used by the BareMetal Operator to set status again.
Once this is done, the operator will remove the status annotation.
In this situation you may also want to check the [detached annotation](./detached_annotation.md) for how to remove the BareMetalHost from the old cluster without going through deprovisioning.

Here is an example of a BareMetalHost, first without the annotation, but with status and spec, and then the other way around.
This shows how the status field is turned into the annotation value.

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: node-0
  namespace: metal3
spec:
  automatedCleaningMode: metadata
  bmc:
    address: redfish+http://192.168.111.1:8000/redfish/v1/Systems/febc9f61-4b7e-411a-ada9-8c722edcee3e
    credentialsName: node-0-bmc-secret
  bootMACAddress: 00:80:1f:e6:f1:8f
  bootMode: legacy
  online: true
status:
  errorCount: 0
  errorMessage: ""
  goodCredentials:
    credentials:
      name: node-0-bmc-secret
      namespace: metal3
    credentialsVersion: "1775"
  hardwareProfile: ""
  lastUpdated: "2022-05-31T06:33:05Z"
  operationHistory:
    deprovision:
      end: null
      start: null
    inspect:
      end: null
      start: "2022-05-31T06:33:05Z"
    provision:
      end: null
      start: null
    register:
      end: "2022-05-31T06:33:05Z"
      start: "2022-05-31T06:32:54Z"
  operationalStatus: OK
  poweredOn: false
  provisioning:
    ID: 8d566f5b-a28f-451b-a70f-419507c480cd
    bootMode: legacy
    image:
      url: ""
    state: inspecting
  triedCredentials:
    credentials:
      name: node-0-bmc-secret
      namespace: metal3
    credentialsVersion: "1775"
```

```yaml
apiVersion: metal3.io/v1alpha1
kind: BareMetalHost
metadata:
  name: node-0
  namespace: metal3
  annotations:
    baremetalhost.metal3.io/status: |
      {"errorCount":0,"errorMessage":"","goodCredentials":{"credentials":{"name":"node-0-bmc-secret","namespace":"metal3"},"credentialsVersion":"1775"},"hardwareProfile":"","lastUpdated":"2022-05-31T06:33:05Z","operationHistory":{"deprovision":{"end":null,"start":null},"inspect":{"end":null,"start":"2022-05-31T06:33:05Z"},"provision":{"end":null,"start":null},"register":{"end":"2022-05-31T06:33:05Z","start":"2022-05-31T06:32:54Z"}},"operationalStatus":"OK","poweredOn":false,"provisioning":{"ID":"8d566f5b-a28f-451b-a70f-419507c480cd","bootMode":"legacy","image":{"url":""},"state":"inspecting"},"triedCredentials":{"credentials":{"name":"node-0-bmc-secret","namespace":"metal3"},"credentialsVersion":"1775"}}
spec:
  ...
```
