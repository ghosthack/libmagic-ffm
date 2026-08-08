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

Use `mvn -Prelease -Dgpg.skip=true clean verify` to check sources, javadocs,
and packaging locally without publishing.
