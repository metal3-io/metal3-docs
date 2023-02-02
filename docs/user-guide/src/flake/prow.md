# Prow flakes

## Multiple PRs stuck in merge queue

At times you will find multiple PR have passed all the tests and also have the required labels `approve` and `lgtm`. All the necessary checks have passed but prow cannot merge them. In such cases, it is mostly found that one of the PRs are not rebased properly. You have to put a hold on that PR and the other PR should go in. Once you rebase and push the first PR, that should also go in without any issue. So `/hold` should do the trick and prow should be able to merge the PR one by one.

## Github Workflow changing PRs not getting merged

PRs which are modifying/adding files in `.github/workflows/` directory do not get merged automatically by Prow. These PRs tend to get stuck inspite of all the tests passed and all the labels present. We have identified that the reason for this is the branch not being present in `upstream` (metal3-io) but in origin (`Nordix`, or other forks). We did not identify the reason behind it. The solution is to push the branch in `upstream`. Once prow detects the branch is present in `upstream`, it will be able to merge the local branch. You don't have to open a PR from `upstream` branch. Only its existense is enough. However only people who have elevated permissions can push branches `upstream` for safety reasons. So if you face such issue please ask assistance by emailing `estjorvas@est.tech`.

## Useful links

[Maintainers guide to tide](https://docs.prow.k8s.io/docs/components/core/tide/maintainers/#expected-behavior-that-might-seem-strange)