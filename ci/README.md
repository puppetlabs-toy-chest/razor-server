CI Template for generating a docker image for use in Jenkins.

# How to build a new image<a name="new-image"></a>

1. Run the [Puppet Docker Build](https://cinext-jenkinsmaster-sre-prod-1.delivery.puppetlabs.net/job/qe_docker_puppet-docker-build) job, pointing the Jenkins job at the correct repo. The arguments should be:
  * GIT_REPO             = puppetlabs/razor-server
  * GIT_REPO_BRANCH      = master
  * GIT_REPO_MODULE_PATH = ci
  * IMAGE_NAME           = qe/razor-server
  * IMAGE_TAG            = latest

# To test a new image

1. Push new code to a private fork and branch.
1. Run the above job, but substitute these arguments, using `$fork`, `$branch_name`, and `$pcr` as
   the proper github fork, github branch name, and private Puppet Container Registry username, respectively:
   ```
   GIT_REPO                 = $fork/razor-server
   GIT_REPO_BRANCH          = $branch_name
   IMAGE_NAME               = $pcr/razor-server
   IMAGE_TAG                = test
   OVERWRITE_EXISTING_IMAGE = true
   ```
   ** Note: The `razor-server` repository must exist in private PCR repository.
1. Update the [Razor unit test job](https://cinext-jenkinsmaster-enterprise-prod-1.delivery.puppetlabs.net/job/platform_razor-server-component_razor-server-component-unit-tests_master_project-master/configure) to temporarily use the new image under "Restrict where this project can be run": `worker:pcr-internal.puppet.net/$private_repo/razor-server:test`
1. Run the Razor unit test job and examine output if it fails.
1. If the Razor unit test job passes, file a PR against origin, merge code, and [run the new image job again](#new-image).
