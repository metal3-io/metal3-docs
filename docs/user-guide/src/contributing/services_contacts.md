# Ops routines for the Metal³ project

Every project has some services that it depends on for running tests, publishing a web page or building container images for example.
Metal³ is no exception.
In this section of the book we try to gather information about these services, who runs them, and how to keep them healthy and secure.

## What services are we responsible for

We need to know which services we use that we are running our selves (i.e. we are responsible for keeping them operational).
It can be complete services (e.g. Prow) that we operate, or things like configuring Jenkins correctly (i.e. we are responsible for configuring the pipelines, but not for keeping Jenkins running).

### Prow

[Prow](https://github.com/kubernetes/test-infra/blob/master/prow/README.md) is a Kubernetes based CI/CD system that we use in Metal³ to run tests and enforce certain policies for our git repositories on GitHub.
Every event in our repositories on GitHub are forwarded to Prow so it can take action when necessary.
It runs in a Kubernetes cluster in Cleura and is publicly exposed so that GitHub can reach it.
The endpoint is protected with token based authentication.

Components:

- crier: Updated the status on pull requests based on tests (e.g. success or fail).
- horoligium: Periodic jobs
- status-reconciler
- deck: The [dashboard for Prow](https://prow.apps.test.metal3.io/).
- controller-manager: Controls the ProwJobs (tests) in Kubernetes.
- ghproxy: Caching between GitHub and Prow.
- hook: Listens for all incoming events, filters them and forwards to the relevant Prow service.
- sinker: Cleans up ProwJobs and old Pods.
- tide: Handles automatic merging of pull requests.

Prow is configured through files in [project-infra](https://github.com/metal3-io/project-infra/tree/main/prow/config).

#### Mino

[Minio](https://min.io/) is used for storing the logs produced by Prow when running tests.
It stores the data in an Azure bucket.

#### Ingress Nginx

[Ingress Nginx](https://kubernetes.github.io/ingress-nginx/deploy/) is used as ingress controller in the cluster.
It is through this we expose the public endpoints, e.g. the Prow dashboard.

#### Cert-manager

[Cert-manager](https://cert-manager.io/) is used for certificate management in the cluster.
This is mainly for getting Let's Encrypt certificates for the Ingresses.

### Prow Kubernetes Cluster

The Kubernetes cluster where Prow is running.

### IDS Wazuh

[Wazuh](https://wazuh.com/) is a "security platform" used to keep the bare metal lab secure.
See [Nordix wiki](https://wiki.nordix.org/pages/viewpage.action?pageId=47546865).

### Jenkins

The [Nordix Jenkins instance](https://jenkins.nordix.org/) is used for all "heavier" tests and build jobs (e.g. integration tests, e2e tests and node image building jobs).
It is managed by the Nordix admins, but we provide the Jenkins agents, pipelines and configure secrets.

The jobs are defined using [Jenkins Job Builder](https://jenkins-job-builder.readthedocs.io/en/latest/) and are stored in the [cicd repo on the Nordix Gerrit](https://gerrit.nordix.org/admin/repos/infra/cicd,general).
Each job references a pipeline in [project-infra](https://github.com/metal3-io/project-infra/tree/main/jenkins/jobs) or [metal3-dev-tools](https://github.com/Nordix/metal3-dev-tools/tree/master/ci/jobs) that is executed by Jenkins when the job is triggered.

### Jump hosts

We have jump hosts in Cleura which are used to avoid having to expose every developer VM to the internet.
See [this wiki page](https://wiki.nordix.org/display/IN/Jumphost+Setup).

### Bare metal lab

We have access to a server rack with actual physical servers.
This is used for some CI jobs as well as for manual testing.
We are responsible for the software on these machines but not for the hardware itself.
More details can be found on the [BML wiki](https://wiki.nordix.org/display/CPI/Bare+Metal+Lab).

## Contact information to those we rely on

When things break, it is often because of issues in the underlying infrastructure.
In these cases we need to know who to contact to report the issues and where to look for known issues (e.g. status pages).

### Cleura

Contanct: <support@cleura.com>

Status page: <https://www.cnstatus.com/>

Cleura (former CityCloud) is the cloud platform we run most of our things on.
All the Jenkins jobs, Prow and all developer VMs are here.
They basically donate the resources to us and the normal support email is available if we need to reach them.

### Nordix services

Contact: <discuss@lists.nordix.org>

The [Nordix association](https://www.nordix.org/) provides several services that we rely on.

- [Gerrit](https://gerrit.nordix.org/): code repositories.
- [Wiki](https://wiki.nordix.org/): gather useful information.
- [Jenkins](https://jenkins.nordix.org/): tests and build jobs.
- [Artifactory](https://artifactory.nordix.org/): store build artifacts.
- [Jira](https://jira.nordix.org): ticket system.

### Quay

Contact: <support@quay.io>

Status page: <https://status.quay.io/>

We use [Quay](https://quay.io) to store the container images for all projects.

### Bare metal lab hardware contact

Contact: Ian Kumlien (<ian.kumlien@ericsson.com>)

Note this is for hardware issues.
We are responsible for the software.
See the [BML wiki](https://wiki.nordix.org/display/CPI/Bare+Metal+Lab).
