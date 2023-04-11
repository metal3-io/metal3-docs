# Prow flakes

## Multiple PRs stuck in merge queue

At times you will find multiple PR have passed all the tests and also have the required labels `approve` and `lgtm`. All the necessary checks have passed but prow cannot merge them. In such cases, it is mostly found that one of the PRs are not rebased properly. You have to put a hold on that PR and the other PR should go in. Once you rebase and push the first PR, that should also go in without any issue. So `/hold` should do the trick and prow should be able to merge the PR one by one.

## Useful links

[Maintainers guide to tide](https://docs.prow.k8s.io/docs/components/core/tide/maintainers/#expected-behavior-that-might-seem-strange)
