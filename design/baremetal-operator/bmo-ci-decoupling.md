# BMO CI Decoupling

Necessity of release and development branches have been acknowledged in metal3-io/baremetal-operator
repository lately and the community has decided to introduce the branching as
well as updating the release policy to maintain the branches. The issue was
raised in <https://github.com/metal3-io/baremetal-operator/issues/1283> and
an update was made to BMO release document <https://github.com/metal3-io/baremetal-operator/pull/1298>
as a result.

As a next step, the following proposal is made for the branching:

- BMO e2e (completely independent of CAPM3) test has to be designed and put in
  place. So far BMO PRs are tested with CAPM3, CAPI and IPAM integration tests
  but with the introduction of BMO release branches and proper releases from
  those branches, BMO should not rely on CAPM3 releases and should be decoupled
  from CAPM3 integration tests when testing a BMO PR. We propose a completely
  independent BMO e2e test framework which will test BMO features with ironic.
  For this few action points have been identified:

   - Simplify BMO deployment through kustomize and get rid of deploy.sh script
   in the process.

   - Introduce BMO e2e test framework similar to what we have currently in CAPM3.

   - Write all the e2e feature tests necessary to test BMO code with ironic
   deployment which would be necessary to test integration of a PR landing in BMO.

- Nightly jobs would be the place where we would test CAPM3 main branch
  integration with BMO main branch. This would help us identify if we need to
  introduce any change in CAPM3/BMO regarding the changes landing in BMO/CAPM3
  repo. Action points:

   - Configure JJBs for different combinations of CAPM3 and BMO releases for
   nightly fullstack jobs. We already test CAPM3 main branch-BMO main branch
   combination in periodic jobs.

   - Configure metal3-io/project-infra and metal3-io/metal3-dev-env to
   accommodate the release branches in the full stack jobs.

- Meanwhile we can branch out BMO to release branch and continue development in
  main branch. Until BMO e2e tests are in place, we can continue testing BMO
  release branch and main branch in the same way we do it currently in dev-envs.
  Instead of using tags which is the way we test currently, we can use branch
  names for specific branches of CAPM3. For example, CAPM3 release-1.5 branch
  will be tested with BMO release-0.4 branch and CAPM3 main branch will be
  tested with BMO main branch. Releasings and branch maintenance is desribed in
  BMO [releasing document](https://github.com/metal3-io/baremetal-operator/blob/main/docs/releasing.md)

- Release  process for BMO need to have proper documentation or uplift
  instructions with detailed guideline for changes needed in BMO consumers (for
  example CAPM3) to uplift BMO in the go module .

- Once BMO e2e tests are in place, metal3-dev-env test defaults should also
  change to test CAPM3 main branch with BMO latest release. This is because we
  can no longer guarantee whether CAPM3 main branch would work with BMO main
  branch as there might be breaking changes in BMO and this could potentially
  block dev-env PRs. Running CAPM3 main against stable BMO release should be
  enough for metal3-dev-env tests.
