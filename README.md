# libmagic-ffm

Java 22 Panama FFM bindings for file/libmagic with bundled, from-source native
libraries and the compiled `magic.mgc` signature database. One Maven
coordinate, batteries included: no JNI and no user-installed libmagic.

| Artifact | Contents | License |
|---|---|---|
| `io.github.ghosthack:libmagic-ffm` | All public functions and API constants, native loader, and Java-friendly `Magic` wrapper | MIT |
| `io.github.ghosthack:libmagic-ffm-natives` (`macos-arm64`, `windows-x64`, `linux-x64`) | file/libmagic 5.48 shared library and `magic.mgc` | BSD-2-Clause |

Status: initial `5.48-0.1.0-SNAPSHOT` implementation. Supported platforms are
macOS ARM64, Windows x64, and Linux x64.

## Use

```xml
<dependency>
  <groupId>io.github.ghosthack</groupId>
  <artifactId>libmagic-ffm</artifactId>
  <version>5.48-0.1.0-SNAPSHOT</version>
</dependency>
<dependency>
  <groupId>io.github.ghosthack</groupId>
  <artifactId>libmagic-ffm-natives</artifactId>
  <version>5.48-0.1.0-SNAPSHOT</version>
  <classifier>macos-arm64</classifier> <!-- windows-x64 / linux-x64 -->
  <scope>runtime</scope>
</dependency>
```

On the module path, declare `requires libmagic.ffm;` and run with
`--enable-native-access=libmagic.ffm`. On the class path, use
`--enable-native-access=ALL-UNNAMED`.

The owning wrapper loads the bundled database automatically:

```java
import io.github.ghosthack.libmagicffm.Magic;
import io.github.ghosthack.libmagicffm.libmagic.LibMagic;

import java.nio.file.Path;

try (Magic magic = Magic.open(LibMagic.MAGIC_MIME_TYPE())) {
    String mime = magic.file(Path.of("photo.jpg"));
    String bufferMime = magic.buffer(bytes);
}
```

The generated C surface is available through `LibMagic` when direct
control of `magic_t`, database buffers, parameters, or descriptors is needed:

```java
int nativeVersion = LibMagic.magic_version(); // 548
```

### Resolution order

1. `-Dlibmagicffm.libdir=<dir>` or `LIBMAGIC_FFM_LIBDIR` loads shared libraries
   from an existing installation.
2. The current platform's natives jar is extracted once to
   `~/.cache/libmagic-ffm/<version>-<platform>/` and loaded.
3. Libraries already loaded by the host process and the native linker's
   default symbols are searched.

Set `-Dlibmagicffm.database=<magic.mgc>` or `LIBMAGIC_FFM_DATABASE` to replace
the bundled database independently. This also makes both the library and its
data user-replaceable.

## Building

Build each native jar on its target platform. On macOS ARM64:

```sh
mkdir -p build
curl -sfL https://www.astron.com/pub/file/file-5.48.tar.gz | tar xz -C build
build-natives/macos-arm64.sh
JEXTRACT_HOME=/path/to/jextract-22 jextract/gen-bindings.sh
mvn clean install
```

The generated Java source is committed; consumers and ordinary builds do not
need jextract. Staged native resources are build outputs and are not committed.
See `tools/README.md` for the jextract 22 download.
