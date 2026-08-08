package io.github.ghosthack.libmagicffm;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.lang.foreign.Arena;
import java.lang.foreign.Linker;
import java.lang.foreign.SymbolLookup;
import java.nio.charset.StandardCharsets;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;

/** Resolves libmagic and its compiled signature database. */
public final class LibMagicLibs {
    private static final Arena LIBRARY_ARENA = Arena.ofAuto();
    private static volatile Resolved resolved;

    private LibMagicLibs() {}

    /** Returns the lookup used by the generated bindings. */
    public static SymbolLookup lookup() {
        return resolve().lookup();
    }

    /**
     * Returns an explicit magic database path, or {@code null} to let libmagic
     * use its system default. The bundled database is extracted on first use.
     */
    public static Path databasePath() {
        String override = firstNonBlank(
                System.getProperty("libmagicffm.database"),
                System.getenv("LIBMAGIC_FFM_DATABASE"));
        return override != null ? Path.of(override) : resolve().database();
    }

    private static Resolved resolve() {
        Resolved r = resolved;
        if (r == null) {
            synchronized (LibMagicLibs.class) {
                r = resolved;
                if (r == null) {
                    resolved = r = resolveOnce();
                }
            }
        }
        return r;
    }

    private static Resolved resolveOnce() {
        String override = firstNonBlank(
                System.getProperty("libmagicffm.libdir"),
                System.getenv("LIBMAGIC_FFM_LIBDIR"));
        Resolved primary = override != null ? fromDirectory(Path.of(override)) : fromBundle();
        SymbolLookup fallback = SymbolLookup.loaderLookup().or(Linker.nativeLinker().defaultLookup());
        return primary == null
                ? new Resolved(fallback, findSystemDatabase())
                : new Resolved(primary.lookup().or(fallback), primary.database());
    }

    private static Resolved fromDirectory(Path dir) {
        if (!Files.isDirectory(dir)) {
            throw new IllegalStateException("libmagicffm.libdir does not exist: " + dir);
        }
        List<Path> libraries = new ArrayList<>();
        try (var files = Files.list(dir)) {
            files.filter(LibMagicLibs::isSharedLibrary).sorted().forEach(libraries::add);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        if (libraries.isEmpty()) {
            throw new IllegalStateException("no libmagic shared library found in " + dir);
        }
        libraries.sort((a, b) -> Boolean.compare(isMagicLibrary(a), isMagicLibrary(b)));
        return new Resolved(chain(libraries), findDatabaseNear(dir));
    }

    private static Resolved fromBundle() {
        String classifier = classifier();
        String base = "natives/" + classifier + "/";
        List<String> libraries = readManifest(base, "manifest.txt");
        if (libraries == null) {
            return null;
        }
        List<String> resources = readManifest(base, "resources.txt");
        Path cacheDir = Path.of(System.getProperty("user.home"), ".cache", "libmagic-ffm",
                Version.VERSION + "-" + classifier);
        try {
            Files.createDirectories(cacheDir);
            List<Path> extractedLibraries = new ArrayList<>();
            for (String name : libraries) {
                extractedLibraries.add(extract(base + name, safeTarget(cacheDir, name)));
            }
            Path database = null;
            if (resources != null) {
                for (String name : resources) {
                    Path target = extract(base + name, safeTarget(cacheDir, name));
                    if (target.getFileName().toString().equals("magic.mgc")) {
                        database = target;
                    }
                }
            }
            return new Resolved(chain(extractedLibraries), database);
        } catch (IOException e) {
            throw new UncheckedIOException("failed to extract bundled libmagic to " + cacheDir, e);
        }
    }

    private static List<String> readManifest(String base, String name) {
        try (InputStream in = LibMagicLibs.class.getClassLoader().getResourceAsStream(base + name)) {
            if (in == null) return null;
            return new String(in.readAllBytes(), StandardCharsets.UTF_8).lines()
                    .map(String::trim)
                    .filter(line -> !line.isEmpty() && !line.startsWith("#"))
                    .toList();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }

    private static Path safeTarget(Path directory, String name) throws IOException {
        Path target = directory.resolve(name).normalize();
        if (!target.startsWith(directory) || Path.of(name).isAbsolute()) {
            throw new IOException("unsafe bundled resource path: " + name);
        }
        Files.createDirectories(target.getParent());
        return target;
    }

    private static Path extract(String resource, Path target) throws IOException {
        try (InputStream in = LibMagicLibs.class.getClassLoader().getResourceAsStream(resource)) {
            if (in == null) throw new IOException("missing classpath resource " + resource);
            byte[] bytes = in.readAllBytes();
            if (Files.exists(target) && Files.size(target) == bytes.length) return target;
            Path tmp = Files.createTempFile(target.getParent(), target.getFileName().toString(), ".tmp");
            try {
                Files.write(tmp, bytes);
                try {
                    Files.move(tmp, target, StandardCopyOption.REPLACE_EXISTING,
                            StandardCopyOption.ATOMIC_MOVE);
                } catch (AtomicMoveNotSupportedException e) {
                    Files.move(tmp, target, StandardCopyOption.REPLACE_EXISTING);
                }
            } finally {
                Files.deleteIfExists(tmp);
            }
            return target;
        }
    }

    private static SymbolLookup chain(List<Path> libraries) {
        SymbolLookup result = null;
        for (Path library : libraries) {
            SymbolLookup one = SymbolLookup.libraryLookup(
                    library.toAbsolutePath().toString(), LIBRARY_ARENA);
            result = result == null ? one : result.or(one);
        }
        return result;
    }

    private static boolean isSharedLibrary(Path path) {
        String name = path.getFileName().toString().toLowerCase();
        return (name.endsWith(".dylib") || name.endsWith(".dll") || name.contains(".so"))
                && (name.contains("magic") || name.startsWith("libgcc")
                || name.startsWith("libwinpthread") || name.startsWith("libbz")
                || name.startsWith("liblzma") || name.startsWith("zlib"));
    }

    private static boolean isMagicLibrary(Path path) {
        String name = path.getFileName().toString().toLowerCase();
        return name.contains("magic") && !name.endsWith(".mgc");
    }

    private static Path findDatabaseNear(Path libraryDirectory) {
        List<Path> candidates = List.of(
                libraryDirectory.resolve("magic.mgc"),
                libraryDirectory.resolve("../share/misc/magic.mgc").normalize(),
                libraryDirectory.resolve("../../share/misc/magic.mgc").normalize());
        return candidates.stream().filter(Files::isRegularFile).findFirst().orElse(findSystemDatabase());
    }

    private static Path findSystemDatabase() {
        for (String name : List.of("/opt/homebrew/share/misc/magic.mgc",
                "/usr/local/share/misc/magic.mgc", "/usr/share/misc/magic.mgc")) {
            Path path = Path.of(name);
            if (Files.isRegularFile(path)) return path;
        }
        return null;
    }

    private static String firstNonBlank(String first, String second) {
        if (first != null && !first.isBlank()) return first;
        return second != null && !second.isBlank() ? second : null;
    }

    static String classifier() {
        String os = System.getProperty("os.name", "").toLowerCase();
        String arch = System.getProperty("os.arch", "").toLowerCase();
        String osPart = os.contains("mac") ? "macos" : os.contains("win") ? "windows" : "linux";
        String archPart = arch.equals("aarch64") || arch.equals("arm64") ? "arm64" : "x64";
        return osPart + "-" + archPart;
    }

    private record Resolved(SymbolLookup lookup, Path database) {}
}
