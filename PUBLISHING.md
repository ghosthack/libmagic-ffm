# Publishing to Maven Central

Publishing is gated by a non-prerelease GitHub Release. Pushes and pull
requests only build and test.

1. Replace the snapshot version in the parent and both module poms with the
   release version, and update versioned documentation.
2. Merge the release commit and wait for CI.
3. Publish a GitHub Release tagged `v<version>` at that exact commit.
4. The release workflow rebuilds all natives, validates the tag, and deploys
   the signed artifacts to Maven Central.

The repository secrets are `MAVEN_CENTRAL_USERNAME`,
`MAVEN_CENTRAL_PASSWORD`, `GPG_PRIVATE_KEY`, and `GPG_PASSPHRASE`.

Use `./mvnw -Prelease -Dgpg.skip=true clean verify` to check sources, javadocs,
and packaging locally without publishing.

Builds use the Maven Wrapper (`./mvnw`), which pins Maven 3.9.16. Do not
switch the release to the runner's `mvn`: under Maven 3.10 the
central-publishing plugin (0.11.0) stages resolver files such as
`_remote.repositories` and `maven-metadata-local.xml` into the bundle, and
Central rejects it with "Bundle has content that does NOT have a .pom file".

To inspect the signed bundle CI would upload, run the Release workflow
manually (optionally with a throwaway `version`). It rebuilds all natives,
builds against an unreachable Central URL with placeholder credentials, and
attaches `central-bundle.zip` as a workflow artifact; nothing is published.
