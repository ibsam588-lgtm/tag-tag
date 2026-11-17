# Main-Only GitHub Actions

All workflow jobs require `github.ref == refs/heads/main`. Push triggers target only `main`; pull-request and tag triggers are removed. Manual runs selected on another branch skip every job. Checkouts use the triggering main commit SHA, not a PR head or a mutable branch.

Existing main-branch platform path filters and explicit upload gates are preserved. A workflow that previously only validated PRs now validates corresponding changes after merge to main.

This policy does not certify native builds, consent, ads or purchases. Follow the app's release-readiness checks before uploading or publishing. Screenshot workflows are not run by this change.
