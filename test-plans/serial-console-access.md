# [5.1] Serial Console Access for BareMetalHosts

## Test Plan Identifier

[`METAL-1923-test-plan`](https://redhat.atlassian.net/browse/METAL-1923)

Tracked by [METAL-2012](https://redhat.atlassian.net/browse/METAL-2012).

---

## 1. Introduction

### Purpose

This test plan validates on-demand serial console access for Metal3 BareMetalHosts. An administrator creates a `HostSerialConsole` request with the same name and namespace as a host. The Bare Metal Operator asks Ironic to open an IPMI serial-over-LAN session and publishes it inside the cluster as a Service on TCP port 2023. Deleting the request closes that access.

This is an IEEE 829-style plan adapted to the Metal team template. It uses that section order. It is not a claim of strict IEEE 829 compliance. It defines what will be tested and how a result passes or fails. Step-by-step procedures are a later deliverable. Before execution, each procedure also needs the build revision, Ironic image digest, environment details, a bounded timeout, and the completion rule in section 9.

### Source of truth

The proposed test baseline is metal3-docs commit `4024d0936f65f055826c05ece376c58ea0699263` on [metal3-docs #751](https://github.com/metal3-io/metal3-docs/pull/751). The document in that commit is still marked provisional. The pull request has an `/approve` and is not merged. Differences from the epic and the parent feature are listed in section 2 as a proposed baseline, pending confirmation from the feature owner. This plan does not treat those differences as already rejected requirements.

| Document | Role in this plan |
| --- | --- |
| [metal3-docs #751](https://github.com/metal3-io/metal3-docs/pull/751) at `4024d093` | Proposed contract |
| [METAL-1923](https://redhat.atlassian.net/browse/METAL-1923) | Epic. Some sentences differ from the design. See section 2 |
| [OCPSTRAT-2044](https://redhat.atlassian.net/browse/OCPSTRAT-2044) | Parent feature. Its ten-second target is unresolved. See section 7 |
| [baremetal-operator #3768](https://github.com/metal3-io/baremetal-operator/pull/3768) | Prototype only. It conflicts with `main` and implements an older, larger design. Do not use it as the pass/fail oracle |
| [Discussion #3728](https://github.com/orgs/metal3-io/discussions/3728) | Background for how the request API was chosen |

If #751 changes after `4024d093`, update this plan before executing the tests.

### Scope

**In scope:**

- `HostSerialConsole` create, status, and delete lifecycle
- `HostSerialConsoles` feature gate, disabled by default
- Ironic `ipmitool-socat` for hosts enrolled after that driver is selected
- IPMI hosts using their existing BMC address and credentials
- Redfish hosts using IPMI on the Redfish hostname, UDP port 623, and the Redfish account
- ClusterIP Service on TCP port 2023, with an EndpointSlice aimed at Ironic's listener
- Cleanup on delete, deprovision, detach, and host deletion, including the order of those steps
- A console opened on an available host remaining reachable if that host is then provisioned
- Two consoles on two different hosts at the same time
- IPv4 and IPv6 Service routing
- Failure and regression behavior defined below

**Out of scope:**

- Web terminals, WebSocket proxies, and OSAC ([OSAC-1202](https://redhat.atlassian.net/browse/OSAC-1202))
- Authenticating the TCP connection, tenant authorization, and HostClaim multi-tenancy
- Session recording, or more than one client sharing one console
- Automatic discovery of a different IPMI address from Redfish
- An explicit console-address override on the BareMetalHost
- Configuring the guest operating system (`console=ttyS0` is a precondition, not a product feature)
- Graphical or VNC consoles
- Opening a new console while the host is registering, inspecting, provisioning, or deprovisioning. Keeping a console that was opened while the host was `available`, across the later provision, is in scope
- Changing the console interface of a host that is already provisioned, unless an administrator puts that host into maintenance or deprovisions it

---

## 2. Background / References

- **Epic:** [METAL-1923](https://redhat.atlassian.net/browse/METAL-1923) — Serial Console API for Metal3
- **Parent feature:** [OCPSTRAT-2044](https://redhat.atlassian.net/browse/OCPSTRAT-2044) — Add capability for Metal3 to expose a serial console
- **Test-plan task:** [METAL-2012](https://redhat.atlassian.net/browse/METAL-2012)
- **Design:** [metal3-docs #751](https://github.com/metal3-io/metal3-docs/pull/751) at `4024d093`
- **Prototype:** [baremetal-operator #3768](https://github.com/metal3-io/baremetal-operator/pull/3768)
- **Ironic console behavior:** [Configuring Consoles](https://docs.openstack.org/ironic/latest/admin/console.html)
- **Virtual hardware:** [VirtualBMC serial-over-LAN](https://review.opendev.org/c/openstack/virtualbmc/+/1008259)
- **Target:** Tech Preview, OpenShift 5.1 (February 2027)

The epic text differs from the revised design in three places. The table is the proposed baseline for this plan. The feature owner still needs to confirm it. Until then, a test does not fail the product for following the design, and this plan does not declare the epic sentences rejected.

| Epic sentence | Design at `4024d093` | Proposed baseline |
| --- | --- | --- |
| Enable and disable through fields on `BareMetalHost`, and publish host/port on BareMetalHost status | A separate `HostSerialConsole` with an empty spec. Status on that request holds the Service name, connection URL, and Ironic node ID | Test the request. Do not require new console fields on BareMetalHost unless the feature owner says the epic sentence still applies |
| Console only after the host is `provisioned` | A new console may be enabled for a stable host, including `available` and `provisioned`. A console opened on an available host stays open across the following provision | Test both states, pending feature-owner confirmation |
| Support `ipmitool-socat` and `redfish-socat` | First version is `ipmitool-socat` only. Redfish hosts use IPMI on the same hostname and account | Test that path. Do not require a `redfish-socat` driver unless the feature owner says it is still in this epic |

The parent feature also asks for kernel-parameter passthrough, a web-style client, tenant session control, and console setup within 10 seconds. The first three are outside the design's non-goals. The 10-second figure is handled in section 7.

---

## 3. Test Items

- `HostSerialConsole` API, admission, finalizer, and status
- `HostSerialConsoles` feature gate and the optional Service / EndpointSlice RBAC component
- Console controller: enable, route, refresh, and clean up
- Ironic provisioner: disable the console during deprovision, including while console reconciliation is suspended
- Ironic deployment configuration: `socat`, `ipmitool`, `ipmitool-socat` selected at enrollment, and `[console] port_range`
- IPMI and same-hostname Redfish credential handling
- User-facing documentation of the two limits below: hosts already provisioned before the driver was selected, and consoles dropped by detach

---

## 4. Features to Be Tested

### Functional requirements

1. **FR-01:** With the feature gate enabled, a `HostSerialConsole` named exactly like a `provisioned` host opens a console and becomes Ready.
2. **FR-02:** The same request succeeds for a host in `available`. The design names `provisioned` and `available` as the stable states. Other states are not given a pass or fail until the design names them.
3. **FR-03:** The request spec is empty. It contains no address and no credentials.
4. **FR-04:** Status reports a Ready condition, the Service name, a connection URL, and the Ironic node ID. Status contains no credentials.
5. **FR-05:** Ready means Ironic and the Service are set up. It does not mean the guest operating system has printed anything.
6. **FR-06:** The Service is ClusterIP, TCP port 2023, has no pod selector, and has an EndpointSlice aimed at Ironic's listener IP. No LoadBalancer or NodePort is created.
7. **FR-07:** A TCP client of that Service receives the guest serial stream when the guest is configured with a serial console. Sending input returns a recognizable guest response.
8. **FR-08:** Deleting the request disables the Ironic console and removes the owned routing. The finalizer remains until both have finished. Routing may disappear before Ironic reports the console disabled. That intermediate state is valid. The request must not finish deleting while either part is unfinished. An already connected client is disconnected by the time cleanup is reported complete, and a new connection then fails.
9. **FR-09:** An open session survives a Bare Metal Operator restart and ordinary reconciliation. Reconciliation after enable does not call Ironic's console-show operation, because that call interrupts the session.
10. **FR-10:** While the host is paused, or while observation fails temporarily, existing routing stays and Ready becomes Unknown. When Ironic is reachable again and the backend stayed up, Ready recovers and the existing session still works. Deleting the request while the host is paused still closes access.
11. **FR-11:** Deprovisioning closes console access without waiting for the console controller. Before teardown is requested, Ironic must report the console disabled. A failed disable stops teardown. If something re-enables the console before deprovision finishes, the provisioner disables it again and does not complete deprovision until that check passes. With only console reconciliation suspended, the host can become `available` while the request is still deleting and its finalizer and routing objects remain. After console reconciliation resumes, that remaining cleanup finishes. The next provision does not open a listener unless a new request exists.
12. **FR-12:** A host with no console request deprovisions as it does today.
13. **FR-13:** The host returns to `available` when deprovision completes. It does not wait for the console controller.
14. **FR-14:** Moving a host from `available` to `provisioning` does not itself revoke a console that was opened while the host was `available`. Access continues. Ready does not have to stay True at every moment during that transition. Deletion, deprovision, detach, and host deletion still close the console under their own rules.
15. **FR-15:** Detach stops the console and deletes the request. After attach, the old request is gone and a new one is required. Deleting the host also closes the console.
16. **FR-16:** The controller does not enable a new console unless the host is in a stable state. It re-reads the host from the API server immediately before enable, and it never enables a request that is being deleted.
17. **FR-17:** An IPMI host uses its existing management address and credentials.
18. **FR-18:** A Redfish host registered while the feature gate is on uses IPMI on the Redfish hostname, the standard IPMI port (UDP 623), and the Redfish username and password. Rotating the BMC secret updates those IPMI settings. A host registered while the gate was off is not given a migration rule by the design.
19. **FR-19:** Hosts enrolled while `ipmitool-socat` is the selected console interface receive that interface. Hosts already provisioned before that configuration do not, until they are deprovisioned or an administrator sets maintenance and changes the interface.
20. **FR-20:** The `HostSerialConsoles` feature gate is alpha and defaults to off. While it is off, no console controller runs and host management does not need Service permissions. While it is on, console create and cleanup work with only create, get, update, and delete on Services and EndpointSlices in the watched namespaces. List and watch on those resources are not required.
21. **FR-21:** A provisioner without console support reports that on the request and does not otherwise change the host.
22. **FR-22:** IPv4 listeners produce an IPv4 Service and EndpointSlice. IPv6 listeners produce an IPv6 Service and EndpointSlice. API-server validation and live traffic are separate results.
23. **FR-23:** If Ironic cannot disable the console, the finalizer stays and the request status reports the failure. After the failed dependency is restored, cleanup finishes and the finalizer is removed.
24. **FR-24:** Service and EndpointSlice names include the request UID. The controller does not modify a Service or an EndpointSlice it does not own. Recreating the request creates new routing objects and a working connection.
25. **FR-25:** Consoles for two different hosts work at the same time. Deleting one request leaves the other usable.

### User-visible outcomes

26. **UG-01:** A user with create, get, and delete permission for `HostSerialConsole`, and without permission to update the BareMetalHost, can create the request, read its endpoint, and delete the request.
27. **UG-02:** An administrator connects with a normal TCP client to the Service on port 2023 and can send input as well as read output.
28. **UG-03:** Documentation states the already-provisioned-host limit and the detach limit before the feature is declared tested.

---

## 5. Features Not to Be Tested

These are non-goals of the revised design. A missing behavior here is not a test failure.

1. Tenant login, an authenticating proxy, or encrypted client transport.
2. A browser terminal, session recording, and two clients using one console at the same time. Two consoles on two hosts are in scope.
3. Automatic Redfish discovery of a different SOL address.
4. A `serialConsoleAddress` field, or separate SOL credentials, on the BareMetalHost.
5. Guest kernel parameters and install-ramdisk console flags (`IRONIC_KERNEL_PARAMS`, `IPA_FORWARD_CONSOLE`).
6. `redfish-graphical` and any VNC console.
7. A `redfish-socat` interface, unless the feature owner confirms that the epic sentence is still in scope.
8. Opening a new console while the host is registering, inspecting, provisioning, or deprovisioning.
9. OSAC, or any product that sits in front of the TCP port.
10. The prototype behaviors that the revised design removed: BMO calling Redfish to discover SOL, BMO watching every Service in the cluster, and a permanent `enabled` flag on the request.

---

## 6. Approach

### Testing strategy

**Unit and API-server tests, owned by development with QE review:**

- Admission, finalizer, and status rules
- Ironic enable and disable calls, including a failed disable and recovery after that failure
- Service and EndpointSlice generation for IPv4 and IPv6
- Feature gate off produces no console reconciliation and needs no Service RBAC
- Feature gate on works without list or watch permission on Services and EndpointSlices

**Integration tests:**

- Suspend only console reconciliation. The BareMetalHost controller and Ironic keep running. Stopping all of BMO would also stop deprovisioning, so that would not test this guarantee. The exact hook is agreed with Honza when the implementation exists
- Teardown is not requested until Ironic confirms the console is disabled. A failed disable prevents teardown
- A re-enabled console is disabled again before deprovision completes
- After console reconciliation resumes, the request finishes deleting
- A stale cache cannot enable a console during deprovision
- Credential rotation on a Redfish host updates the IPMI password used for SOL

**End-to-end tests:**

- VirtualBMC with serial-over-LAN for the main lifecycle: guest output, interactive input, operator restart, pause, delete of an already connected client, reconnect with a new request, two hosts at once, and no listener after reprovision
- One real IPMI machine and one real Redfish machine whose IPMI listener is the Redfish hostname on UDP 623

**Manual checks:**

- Documentation of the already-provisioned and detach limits
- Confirmation that a guest without a serial console can still show Ready while the TCP connection is empty

### Environment tiers

1. **Development:** Metal3 dev environment, or an equivalent cluster, with VirtualBMC SOL
2. **CI:** unit tests and API-server tests on every controller and API change
3. **Staging:** real IPMI and qualifying Redfish hardware
4. **OpenShift:** the same lifecycle on a cluster whose Ironic image contains `socat` and the console driver. This tier is blocked until that image change exists

### Test phases

1. **Phase 1 — Functional:** FR-01 through FR-16, FR-24, and FR-25 on VirtualBMC
2. **Phase 2 — Connections:** FR-17 and FR-18, virtual first and then real hardware
3. **Phase 3 — Install and upgrade:** FR-19, FR-20, and FR-21
4. **Phase 4 — Non-functional:** security of status and RBAC, IPv6, stuck cleanup and recovery
5. **Phase 5 — Regression:** provisioning, deprovision, power, and inspection with the gate off and with the gate on but no request
6. **Phase 6 — Documentation:** UG-03

---

## 7. Item Pass/Fail Criteria

| Test item | Pass | Fail |
| --- | --- | --- |
| Open on a provisioned host | Request becomes Ready, Service exists on port 2023, and a serial-configured guest is readable and accepts input | Request stays unready with a healthy backend, or no Service is created |
| Open on an available host | Same result as a provisioned host | Request is rejected only because the host is `available` |
| Empty spec | Request has no address or credential fields | API accepts connection settings on the request |
| Status safety | Ready, Service name, URL, and Ironic node ID are set. No password appears in status or controller logs | Credentials are copied into status or logs |
| Ready meaning | Ready is true when routing exists, including when the guest prints nothing | Ready is defined as "guest output was seen" |
| Service shape | ClusterIP, TCP 2023, no selector, EndpointSlice points at an IP, no LoadBalancer or NodePort | A public Service type is created, or the endpoint is a DNS name |
| Guest session | Configured guest text is visible through the Service, and input produces a recognizable guest response | The Service is Ready but a correctly configured guest produces no stream, or input is ignored |
| Delete | The finalizer remains until backend disable is confirmed and owned routing is removed. An existing client connection closes, and new connections fail, after cleanup is reported complete | The request finishes deleting while either cleanup operation is incomplete, or access remains usable after cleanup is reported complete |
| Restart | The TCP session still works after the operator restarts | Restart drops the session, or reconcile itself disconnects it |
| Pause and blip | Routing remains and Ready is Unknown. After Ironic returns, Ready recovers and the existing session still works if the backend stayed up. Delete during pause still closes access | Routing is deleted because of a pause or a short Ironic error, or delete during pause leaves access usable |
| Deprovision | Teardown is not requested until Ironic confirms the console is disabled. A failed disable stops teardown. A console re-enabled in flight is disabled again before deprovision completes. With console reconciliation suspended, the host can become available while the request is still deleting. After that reconciliation resumes, routing cleanup finishes. The next provision does not open a listener without a new request | Teardown starts while the console is still enabled, deprovision completes while the console is enabled, or the next workload's console is listening without a new request |
| Host without a console | Deprovision timing and result match a build without this feature | Deprovision waits on console cleanup or fails |
| Available, then provision | The existing console stays usable across provision. Ready need not stay True at every instant | Provision itself deletes or disables that console |
| Detach and host delete | Request and listener are gone. A new request is required after attach | The old request becomes Ready again on reattach |
| Unstable states | No new enable while the host is registering, inspecting, provisioning, or deprovisioning, or while the request is deleting | A new console is enabled from a stale "provisioned" cache |
| Two hosts | Both consoles work. Deleting one leaves the other usable | One request affects the other host's console |
| IPMI credentials | SOL uses the host's management address and secret | A second secret or address is required |
| Redfish credentials | SOL uses the Redfish hostname, UDP 623, and the Redfish account. Secret rotation is picked up | The test reaches a different IPMI address, or rotation leaves the old password |
| Enrollment | Newly enrolled supported hosts get `ipmitool-socat`. Already provisioned hosts fail the request with a clear status until maintenance or deprovision | BMO puts a running host into maintenance by itself, or a new host enrolls without the driver when the Ironic config selects it |
| Feature gate | Default install has no console controller and no Service RBAC requirement. With the gate on, create and cleanup work without list or watch on Services and EndpointSlices. Enabling the gate without the Ironic driver returns an error on the request and does not break host reconciliation | An install that leaves the gate off fails because Service permissions are missing, or the enabled feature works only when the test environment grants list or watch |
| Unsupported provisioner | Request status explains that consoles are unsupported. Host power and provisioning still work | The host controller fails because the provisioner has no console method |
| IP family | EndpointSlice address family matches the Ironic listener, both in API-server objects and, when an environment exists, in live traffic | An IPv6 listener is published on an IPv4 Service, or the reverse |
| Stuck cleanup | Finalizer and an error condition remain when Ironic will not disable. After the dependency is restored, the finalizer is removed | The request is force-removed and the console stays enabled with no visible error, or a restored dependency never finishes cleanup |
| Owned routing | Recreate produces a new Service and a working connection. A Service or EndpointSlice the controller does not own is left alone | The controller adopts or rewrites a foreign Service or EndpointSlice, or the new request has no working connection |
| RBAC split | A user with create, get, and delete on the request, and without BMH update, can create the request, read its endpoint, and delete it. A user without create permission cannot create a request | Opening a console requires host edit permission, or any authenticated user can create a request |
| Regression | Gate off, and gate on with no request, still register, inspect, provision, power, and deprovision | Those flows fail only because the console feature exists |

The parent feature names a 10-second setup target. The epic does not repeat it, and that does not by itself cancel it. Record time-to-Ready. Do not fail the feature on 10 seconds unless the feature owner confirms that the parent target applies to METAL-1923.

Each procedure gets its own execution timeout, agreed before the run. The timeout only stops a hung procedure. It is not a product performance promise.

---

## 8. Suspension Criteria and Resumption Requirements

### Suspension criteria

Stop the run if any of these happen outside a test that deliberately injects that condition:

1. The test cluster or Ironic becomes unavailable.
2. A console stays enabled in Ironic after deprovision completes.
3. The next provision starts a listener without a new `HostSerialConsole`.
4. A BMC password appears in request status, a Service, an event, or a controller log.
5. The operator fails to reconcile ordinary hosts when the feature gate is off.
6. The design changes the lifecycle this plan tests after commit `4024d093`.

A test that deliberately makes Ironic unreachable, or deliberately makes disable fail, continues. Those cases expect Ready Unknown or a retained finalizer. They are not a reason to suspend the run.

### Resumption requirements

Resume when:

1. The blocking defect is fixed on the build under test.
2. This plan is updated if #751 moved past `4024d093`, and the feature owner has accepted the update.
3. The failed test is run again, and so are the lifecycle tests that depend on it. A registration smoke test alone is not enough.

---

## 9. Test Deliverables

1. This IEEE 829-style plan, adapted to the team template.
2. Coverage map in section 17. Full procedures are written later, per section 19.
3. Results report: pass, fail, blocked, or deferred for each test ID, with the build revision and Ironic image digest.
4. Jira defects for failures, each naming the test ID.
5. A note of measured time-to-Ready, kept separate from pass/fail.
6. Hardware notes for the real IPMI and Redfish systems used.
7. CI job links for the automated cases once those jobs exist.

### When testing is complete

Testing of this plan is complete only when all three are true:

- Every required case has passed on the agreed build.
- Every blocked case is still visible, with the reason recorded.
- Any deferred case or unresolved defect has a written disposition from QE and the feature owner.

A green registration smoke test does not close the plan.

---

## 10. Testing Tasks

1. Confirm #751 is still at `4024d093`, or update this plan if it is not, on the day execution starts.
2. Identify the implementation pull requests that replace #3768. Do not execute this plan against #3768.
3. Confirm the Ironic image under test installs `socat` and `ipmitool`, selects `ipmitool-socat` for new enrollment, and sets `[console] port_range`. Record the image digest.
4. Agree a bounded execution timeout for each procedure before running it.
5. Bring up VirtualBMC with serial-over-LAN and a guest image that uses `console=ttyS0,115200`.
6. Bring up a second guest image that does not use a serial console, for the Ready-versus-output case.
7. Execute Phase 1 functional cases and Phase 5 regression cases.
8. Execute the Redfish same-hostname cases on virtual hardware if the virtual BMC supports that shape, then on one real Redfish machine.
9. Execute the negative and security cases.
10. Read the user docs for the already-provisioned and detach limits.
11. File defects and publish the results report on METAL-2012.

---

## 11. Environmental Needs

### Cluster

- Kubernetes or OpenShift with Bare Metal Operator installed
- `HostSerialConsoles` available and off by default
- For enabled runs, the optional RBAC component with create, get, update, and delete on Services and EndpointSlices in the watched namespaces, and without list or watch
- Permission to create, get, and delete `HostSerialConsole` in the host namespace
- A way to suspend console reconciliation without stopping the BareMetalHost controller or Ironic

### Ironic

- `ipmitool` and `socat` installed in the Ironic image
- `ipmitool-socat` enabled and listed first for hardware types that support it
- `[console] port_range` set to a range the test cluster can route to
- The listener address must be an IP, not a hostname
- Hardware types that do not support `ipmitool-socat` must still be able to enroll

### Hosts

- Two virtual IPMI hosts with VirtualBMC SOL, so two consoles can be open together
- One guest built with serial console output, and one without
- One real IPMI host
- One real Redfish host with IPMI over LAN enabled on the Redfish hostname, UDP 623, using the same account as Redfish
- A Redfish host whose IPMI listener is on a different address is a negative fixture, not a supported setup

Build revisions and image digests are recorded in the results report. They are not known at plan-draft time.

### Blocked until

End-to-end execution is blocked until an Ironic image build contains `socat` and the console interface selection. Unit and API-server tests are not blocked on that image. Live IPv6 traffic is blocked until an IPv6 cluster exists. API-server IPv6 validation is not blocked on that cluster.

---

## 12. Responsibilities

| Activity | Owner |
| --- | --- |
| Feature and design | Honza Pokorny |
| Design review | Dmitry Tantsur, Tuomo |
| This test plan | Salwa Naoum |
| Test-plan review | Steeve Goveas |
| Confirmation of epic differences and the 10-second target | Honza Pokorny |
| Implementation tests in the operator repositories | Feature author, with QE review of coverage |
| Execution and defects | Salwa Naoum, after the implementation pull requests exist |
| Ironic image prerequisites | Owner of `ironic-image`, coordinated with Honza |

---

## 13. Staffing and Training Needs

The person executing the plan needs to be able to:

- Create a BareMetalHost and watch it reach `available` and `provisioned`
- Create and delete a namespaced custom resource
- Open a TCP connection to a Service and type into it (`nc` or an equivalent client)
- Read Ironic node console state without pasting BMC passwords into the report
- Tell a guest-configuration problem (blank screen, Ready true) from a product defect

No separate course is required. Reading this plan and [metal3-docs #751](https://github.com/metal3-io/metal3-docs/pull/751) at `4024d093` is the training. Task-hour estimates belong with the procedure write-up, before execution, not in this draft.

---

## 14. Schedule

| Milestone | When |
| --- | --- |
| Plan drafted | 2026-11-10 |
| Plan review | After Steeve's review, before execution |
| Design agreement | When #751 leaves provisional status |
| Automated tests | With the focused implementation pull requests |
| VirtualBMC end-to-end | After the Ironic image prerequisites exist |
| Real hardware | After the virtual lifecycle passes |
| Tech Preview target | OpenShift 5.1, February 2027 |

Dates for execution are not committed here. #3768 is not the build to schedule against.

---

## 15. Risks and Contingencies

| Risk | What we do |
| --- | --- |
| #751 is still provisional and can change after `4024d093` | This plan is a draft. Re-read #751 before execution and revise affected test IDs |
| The feature owner keeps an epic or parent-feature sentence that the design dropped | Section 2 stays a proposal until Honza confirms it. Do not close those gaps silently |
| #3768 does not match the revised design | Do not file prototype gaps as product failures against this plan |
| Stock Ironic image has no `socat` and does not select `ipmitool-socat` | Mark end-to-end cases blocked. Do not weaken the pass criteria |
| A blank screen is reported as a product bug | Require the serial-configured guest for FR-07. Keep the empty-guest case on FR-05 |
| Redfish BMC does not enable IPMI over LAN, or uses another address | That host is outside the first version. Record it as unsupported, not as a failure |
| Already provisioned hosts cannot switch console interface | This is specified behavior. Fail the product only if a newly enrolled host also cannot, or if the request fails with no explanation |
| TCP clients are not authenticated | Confirm a user without create permission cannot create a request. Do not expect the Service itself to ask for a password, and do not claim that user cannot reach an existing listener |
| Detach drops the console | Specified. Confirm the docs say the user must create a new request after attach |
| Ironic would reopen SOL on the next deploy if BMO did nothing | FR-11 is the release-critical case. Suspend testing if it fails outside a deliberate failure-injection test |
| The console controller cannot be suspended on its own | Agree the test hook with Honza before running TC-FUNC-11. Do not stop all of BMO and treat that as this test |

---

## 16. Approvals

| Role | Name | Responsibility | Date | Result |
| --- | --- | --- | --- | --- |
| Author | Salwa Naoum | Wrote the plan | 2026-11-10 | Draft |
| QE review | Steeve Goveas | Confirms the team template and coverage | | |
| Feature owner | Honza Pokorny | Confirms the plan matches #751, including section 2 and the 10-second target | | |
| Design reviewer | Dmitry Tantsur | Optional. Needed if #751 is still moving | | |

Execution starts after QE review and feature-owner confirmation. It does not wait for the optional design signature once #751 has been merged.

---

## 17. Test Coverage Mapping (Appendix)

Full steps, commands, and expected YAML are written later. This section maps each requirement to a test ID.

**Complete** means the mapping exists. It does not mean the procedure has been written, and it does not mean the test has passed.

**Partial** means part of the requirement has an ID and the rest is named as a gap.

**Blocked** means the mapping exists and execution cannot start until the named dependency exists.

### 17.1 Functional lifecycle

| ID | Title | Requirement | Coverage |
| --- | --- | --- | --- |
| TC-FUNC-01 | Open a console for a provisioned host, with an owner reference to that host | FR-01, FR-04, FR-06 | Complete |
| TC-FUNC-02 | Open a console for an available host | FR-02 | Complete |
| TC-FUNC-03 | Request spec stays empty | FR-03 | Complete |
| TC-FUNC-04 | Read the guest and send input through Service port 2023 | FR-07, UG-02 | Complete |
| TC-FUNC-05 | Ready with a guest that has no serial console | FR-05 | Complete |
| TC-FUNC-06 | Delete keeps the finalizer until disable and routing removal are both done, and closes an existing client | FR-08 | Complete |
| TC-FUNC-07 | Session survives operator restart | FR-09 | Complete |
| TC-FUNC-08 | Reconcile after Ready does not drop the session | FR-09 | Complete |
| TC-FUNC-09 | Pause keeps routing and sets Ready Unknown | FR-10 | Complete |
| TC-FUNC-10 | After a short Ironic outage, Ready recovers and the existing session still works | FR-10 | Complete |
| TC-FUNC-11 | With only console reconciliation suspended, teardown waits for a confirmed disable, the host can become available while the request is still deleting, and cleanup finishes after reconciliation resumes | FR-11, FR-13 | Complete |
| TC-FUNC-12 | Next provision does not reopen the listener | FR-11 | Complete |
| TC-FUNC-13 | Deprovision a host that never had a console | FR-12 | Complete |
| TC-FUNC-14 | An existing available-host console stays usable across provision | FR-14 | Complete |
| TC-FUNC-15 | Detach deletes the request; reattach does not restore it | FR-15 | Complete |
| TC-FUNC-16 | Deleting the host closes the console | FR-15 | Complete |
| TC-FUNC-17 | No new enable during inspect, provision, or deprovision | FR-16 | Complete |
| TC-FUNC-18 | A failed disable stops teardown. If the console is re-enabled in flight, the final check disables it again before deprovision completes | FR-11, FR-16 | Complete |
| TC-FUNC-19 | Recreate the request, get a new Service, and open a working connection | FR-24 | Complete |
| TC-FUNC-20 | EndpointSlice follows a moved Ironic listener | Design routing rule | Partial. Run when a test can move the listener. Otherwise record as a gap, not a pass |
| TC-FUNC-21 | Two hosts have working consoles; deleting one leaves the other usable | FR-25 | Complete |
| TC-FUNC-22 | Delete while the host is paused still closes access | FR-10 | Complete |

### 17.2 Connection setup

| ID | Title | Requirement | Coverage |
| --- | --- | --- | --- |
| TC-CONN-01 | IPMI host uses the management address and secret | FR-17 | Complete |
| TC-CONN-02 | Redfish host uses hostname, UDP 623, and the Redfish account | FR-18 | Complete |
| TC-CONN-03 | Rotating the BMC secret updates Redfish SOL credentials | FR-18 | Complete |
| TC-CONN-04 | New enrollment selects `ipmitool-socat` | FR-19 | Complete |
| TC-CONN-05 | Already provisioned host does not switch interface by itself | FR-19 | Complete |
| TC-CONN-06 | Maintenance path: administrator changes the interface, then the request works | FR-19 | Complete |
| TC-CONN-07 | Hardware type without `ipmitool-socat` still enrolls | Dependencies | Complete |

### 17.3 Deployment and failure

| ID | Title | Requirement | Coverage |
| --- | --- | --- | --- |
| TC-DEP-01 | Feature gate off: hosts reconcile, and no Service RBAC is required | FR-20 | Complete |
| TC-DEP-02 | Feature gate on, with create, get, update, and delete on Services and EndpointSlices, and without list or watch: create and cleanup work | FR-20 | Complete |
| TC-DEP-03 | Feature gate on, Ironic driver missing: request errors, hosts still reconcile | FR-20 | Complete |
| TC-DEP-04 | Unsupported provisioner reports status and does not break the host | FR-21 | Complete |
| TC-DEP-05 | API-server validation of an IPv4 Service and EndpointSlice | FR-22 | Complete for the API object. This does not prove live IPv4 traffic. Live traffic is TC-FUNC-04 |
| TC-DEP-06 | API-server validation of an IPv6 Service and EndpointSlice | FR-22 | Complete for the API object only |
| TC-DEP-07 | Live IPv6 client traffic | FR-22 | Blocked until an IPv6 cluster exists |
| TC-DEP-08 | Ironic refuses to disable: finalizer and error remain | FR-23 | Complete |
| TC-DEP-09 | After that dependency is restored, cleanup finishes and the finalizer is removed | FR-23 | Complete |
| TC-DEP-10 | Host or BMC secret disappears during cleanup | Design: cleanup still finishes | Complete |
| TC-DEP-11 | Downgrade: delete requests and wait until they are gone before turning the gate off | Upgrade section of #751 | Complete |

### 17.4 Negative cases

| ID | Title | Boundary | Coverage |
| --- | --- | --- | --- |
| TC-NEG-01 | Request name does not match a host | Admission | Complete |
| TC-NEG-02 | Host is deleting | Admission | Complete |
| TC-NEG-03 | Host is detached | Admission | Complete |
| TC-NEG-04 | Request in another namespace | Same-namespace rule | Complete |
| TC-NEG-05 | User without create permission cannot create a console request | UG-01 | Complete |
| TC-NEG-06 | User with create, get, and delete, and without BMH update, can create, read the endpoint, and delete | UG-01 | Complete |
| TC-NEG-07 | Redfish host whose IPMI listener is a different address | Unsupported in the first version | Complete |
| TC-NEG-08 | Controller does not modify a Service or an EndpointSlice it does not own | FR-24 | Complete |
| TC-NEG-09 | No LoadBalancer or NodePort is created | FR-06 | Complete |
| TC-NEG-10 | Enabling the feature does not create a web or WebSocket endpoint | Non-goal | Complete |
| TC-NEG-11 | A second TCP client on the same console is not a supported success | Non-goal | Complete. Record what happens. Do not fail the feature if the second client is refused |

### 17.5 Security

| ID | Title | Requirement | Coverage |
| --- | --- | --- | --- |
| TC-SEC-01 | BMC password is absent from status, events, and controller logs | FR-04 | Complete |
| TC-SEC-02 | The Service does not add its own authentication | Known limit, must be documented | Complete |
| TC-SEC-03 | A user who cannot create `HostSerialConsole` cannot create a console request | RBAC | Complete. This does not claim that user cannot connect to an existing listener if the network allows it |

TCP reachability of the Ironic listener outside the Service is an environment control. This plan does not claim the product blocks that path.

### 17.6 Regression

| ID | Title | Target | Coverage |
| --- | --- | --- | --- |
| TC-REG-01 | Register, inspect, provision, and deprovision with the gate off | Existing host lifecycle | Complete |
| TC-REG-02 | Same lifecycle with the gate on and no console request | Existing host lifecycle | Complete |
| TC-REG-03 | Power on and off during a Ready console | Power must keep working | Complete |
| TC-REG-04 | Inspection of a host that has never had a console | Inspection | Complete |
| TC-REG-05 | BareMetalHost spec has no new required console fields | #751: no BMH API change for the first version | Complete |

### 17.7 Documentation

| ID | Title | Requirement | Coverage |
| --- | --- | --- | --- |
| TC-DOC-01 | Docs say an already provisioned host needs deprovision or maintenance before a console works | UG-03, FR-19 | Blocked on the user doc |
| TC-DOC-02 | Docs say detach and host deletion drop the console and a new request is required | UG-03, FR-15 | Blocked on the user doc |
| TC-DOC-03 | Docs say Redfish support is same hostname, UDP 623, same account, and that IPMI over LAN must be enabled | FR-18 | Blocked on the user doc |
| TC-DOC-04 | Docs say the Service does not authenticate the TCP client | Security risk in #751 | Blocked on the user doc |

### 17.8 Epic and parent sentences pending confirmation

| Wording | Proposed baseline |
| --- | --- |
| Console fields on BareMetalHost status | Pending Honza. This plan tests request status (TC-FUNC-01) and no new required BMH fields (TC-REG-05) |
| Console only when provisioned | Pending Honza. TC-FUNC-02 and TC-FUNC-14 follow the design |
| `redfish-socat` | Pending Honza. TC-CONN-02 covers the Redfish path the design specifies |
| Parent-feature web client and kernel passthrough | Outside the design non-goals. TC-NEG-10 |
| Parent-feature 10-second setup target | Pending Honza. Measured, not a pass/fail number, until he confirms it |

---

## 18. Readiness Integration

Link this plan from [METAL-2012](https://redhat.atlassian.net/browse/METAL-2012) and from [METAL-1923](https://redhat.atlassian.net/browse/METAL-1923).

Proposed location: `test-plans/serial-console-access.md` in [metal3-io/metal3-docs](https://github.com/metal3-io/metal3-docs), in its own pull request. That is the repository of the serial console design. This plan is not part of the fast-inspection work or of [cluster-baremetal-operator #692](https://github.com/openshift/cluster-baremetal-operator/pull/692). Do not put it in `openshift/release`.

Suggested follow-on work items, after this plan is accepted:

- Author procedures for TC-FUNC-01 through TC-FUNC-22, including the execution timeout for each one
- Author the deprovision procedure for TC-FUNC-11, TC-FUNC-12, and TC-FUNC-18, including how console reconciliation is suspended
- Author Redfish same-hostname procedures (TC-CONN-02, TC-CONN-03, TC-NEG-07)
- Track the Ironic image prerequisite as its own task
- Execute virtual end-to-end and file the results on METAL-2012

---

## 19. Expansion Requests

This file intentionally stops at test IDs and pass criteria. Ask for procedures one group at a time:

- "Expand TC-FUNC-01 through TC-FUNC-08"
- "Expand the deprovision cases TC-FUNC-11, TC-FUNC-12, and TC-FUNC-18"
- "Expand the Redfish cases TC-CONN-02, TC-CONN-03, and TC-NEG-07"

---

**Document version:** 1.1
**Last updated:** 2026-11-10
**Status:** Draft — pending review by Steeve Goveas and Honza Pokorny
**Contract reviewed against:** metal3-docs #751 commit `4024d093` (2026-11-09), METAL-1923 as of 2026-11-10, baremetal-operator #3768 as of 2026-11-02
