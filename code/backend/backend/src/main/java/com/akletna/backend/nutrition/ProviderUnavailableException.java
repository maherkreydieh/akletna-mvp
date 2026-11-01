package com.akletna.backend.nutrition;

/** Deliberately excludes remote bodies, URLs and credentials. */
public class ProviderUnavailableException extends RuntimeException {
    public ProviderUnavailableException() { super("Nutrition provider is unavailable. Try again later."); }
}
