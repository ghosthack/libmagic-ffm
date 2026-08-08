package io.github.ghosthack.libmagicffm;

import io.github.ghosthack.libmagicffm.libmagic.LibMagic;
import org.junit.jupiter.api.Test;

import java.lang.foreign.Arena;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class SmokeTest {
    @Test
    void bundledNativeReportsExpectedVersion() {
        assertEquals(548, LibMagic.magic_version());
    }

    @Test
    void identifiesBufferWithBundledDatabase() {
        try (Magic magic = Magic.open(LibMagic.MAGIC_MIME_TYPE())) {
            assertEquals("text/plain", magic.buffer("hello, libmagic\n".getBytes(StandardCharsets.UTF_8)));
            try (Arena arena = Arena.ofConfined()) {
                byte[] text = "native text\n".getBytes(StandardCharsets.UTF_8);
                var nativeText = arena.allocate(text.length);
                nativeText.copyFrom(java.lang.foreign.MemorySegment.ofArray(text));
                assertEquals("text/plain", magic.buffer(nativeText));
            }
            assertEquals(LibMagic.MAGIC_MIME_TYPE(), magic.flags());
        }
    }

    @Test
    void identifiesFileAndRejectsUseAfterClose() throws Exception {
        Path file = Files.createTempFile("libmagic-ffm-", ".txt");
        Files.writeString(file, "a plain text fixture\n");
        Magic magic = Magic.open();
        try {
            assertTrue(magic.file(file).toLowerCase().contains("text"));
        } finally {
            magic.close();
            Files.deleteIfExists(file);
        }
        magic.close(); // idempotent
        assertThrows(IllegalStateException.class, () -> magic.file(file));
    }

    @Test
    void surfacesNativeErrors() {
        try (Magic magic = Magic.open(LibMagic.MAGIC_ERROR())) {
            MagicException error = assertThrows(MagicException.class,
                    () -> magic.file(Path.of("definitely", "not", "present", "libmagic-ffm")));
            assertTrue(error.errorNumber() > 0);
            assertTrue(error.getMessage().contains("magic_file failed"));
        }
    }
}
