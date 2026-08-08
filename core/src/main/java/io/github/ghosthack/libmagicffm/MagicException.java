package io.github.ghosthack.libmagicffm;

/** An error reported by libmagic. */
public final class MagicException extends RuntimeException {
    private final int errorNumber;

    MagicException(String message, int errorNumber) {
        super(message);
        this.errorNumber = errorNumber;
    }

    /** Returns libmagic's errno value, or zero when none was available. */
    public int errorNumber() {
        return errorNumber;
    }
}
