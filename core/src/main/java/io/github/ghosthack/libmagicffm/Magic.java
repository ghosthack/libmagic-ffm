package io.github.ghosthack.libmagicffm;

import io.github.ghosthack.libmagicffm.libmagic.LibMagic;

import java.lang.foreign.Arena;
import java.lang.foreign.MemorySegment;
import java.nio.file.Path;
import java.util.Objects;

/**
 * An owning, Java-friendly libmagic handle.
 *
 * <p>Instances are not thread-safe. Each returned native string is copied to
 * a Java string before the next libmagic call can invalidate it.</p>
 */
public final class Magic implements AutoCloseable {
    private MemorySegment cookie;

    private Magic(MemorySegment cookie) {
        this.cookie = cookie;
    }

    /** Opens a handle with {@link LibMagic#MAGIC_NONE()} and loads the bundled database. */
    public static Magic open() {
        return open(LibMagic.MAGIC_NONE());
    }

    /** Opens a handle with {@code flags} and loads the configured or bundled database. */
    public static Magic open(int flags) {
        MemorySegment cookie = LibMagic.magic_open(flags);
        if (cookie.equals(MemorySegment.NULL)) {
            throw new MagicException("magic_open failed", 0);
        }
        Magic magic = new Magic(cookie);
        try (Arena arena = Arena.ofConfined()) {
            Path database = LibMagicLibs.databasePath();
            MemorySegment path = database == null
                    ? MemorySegment.NULL
                    : arena.allocateFrom(database.toString());
            magic.check(LibMagic.magic_load(cookie, path), "magic_load");
            return magic;
        } catch (RuntimeException e) {
            magic.close();
            throw e;
        }
    }

    /** Identifies a file by path. */
    public String file(Path path) {
        return file(Objects.requireNonNull(path, "path").toString());
    }

    /** Identifies a file by path. */
    public String file(String path) {
        Objects.requireNonNull(path, "path");
        try (Arena arena = Arena.ofConfined()) {
            return result(LibMagic.magic_file(requireOpen(), arena.allocateFrom(path)), "magic_file");
        }
    }

    /** Identifies bytes, copying heap segments to temporary native memory when needed. */
    public String buffer(MemorySegment bytes) {
        Objects.requireNonNull(bytes, "bytes");
        if (bytes.isNative()) {
            return result(LibMagic.magic_buffer(requireOpen(), bytes, bytes.byteSize()), "magic_buffer");
        }
        try (Arena arena = Arena.ofConfined()) {
            MemorySegment nativeBytes = arena.allocate(bytes.byteSize(), 1);
            nativeBytes.copyFrom(bytes);
            return result(LibMagic.magic_buffer(requireOpen(), nativeBytes, nativeBytes.byteSize()),
                    "magic_buffer");
        }
    }

    /** Identifies a byte array. */
    public String buffer(byte[] bytes) {
        Objects.requireNonNull(bytes, "bytes");
        return buffer(MemorySegment.ofArray(bytes));
    }

    /** Identifies the contents available through an open native file descriptor. */
    public String descriptor(int descriptor) {
        return result(LibMagic.magic_descriptor(requireOpen(), descriptor), "magic_descriptor");
    }

    /** Returns the current flags. */
    public int flags() {
        return LibMagic.magic_getflags(requireOpen());
    }

    /** Replaces the current flags. */
    public void flags(int flags) {
        check(LibMagic.magic_setflags(requireOpen(), flags), "magic_setflags");
    }

    /** Returns the current libmagic error, or {@code null}. */
    public String error() {
        MemorySegment message = LibMagic.magic_error(requireOpen());
        return message.equals(MemorySegment.NULL) ? null : message.reinterpret(Long.MAX_VALUE).getString(0);
    }

    /** Returns the current libmagic errno value. */
    public int errorNumber() {
        return LibMagic.magic_errno(requireOpen());
    }

    @Override
    public void close() {
        MemorySegment current = cookie;
        if (!current.equals(MemorySegment.NULL)) {
            cookie = MemorySegment.NULL;
            LibMagic.magic_close(current);
        }
    }

    private MemorySegment requireOpen() {
        if (cookie.equals(MemorySegment.NULL)) throw new IllegalStateException("Magic handle is closed");
        return cookie;
    }

    private String result(MemorySegment value, String operation) {
        if (value.equals(MemorySegment.NULL)) throw failure(operation);
        return value.reinterpret(Long.MAX_VALUE).getString(0);
    }

    private void check(int status, String operation) {
        if (status != 0) throw failure(operation);
    }

    private MagicException failure(String operation) {
        String message = error();
        return new MagicException(operation + " failed" + (message == null ? "" : ": " + message),
                errorNumber());
    }
}
