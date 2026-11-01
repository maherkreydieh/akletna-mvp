package com.akletna.backend.security;

import java.nio.charset.StandardCharsets;
import java.security.*;
import java.time.*;
import java.util.*;

/** Safe reset-token primitives. Not an exposed reset endpoint or email transport. */
public final class ResetTokens {
    private final SecureRandom random=new SecureRandom();
    public record Issued(String raw, String hash, Instant expiresAt) {
        @Override public String toString() { return "Issued[REDACTED]"; }
    }
    public Issued issue(Instant now) {
        byte[] entropy=new byte[32]; random.nextBytes(entropy);
        String raw=Base64.getUrlEncoder().withoutPadding().encodeToString(entropy);
        return new Issued(raw,hash(raw),now.plus(Duration.ofMinutes(20)));
    }
    public static String hash(String raw) {
        if(raw==null || !raw.matches("[A-Za-z0-9_-]{43}")) throw new IllegalArgumentException("Invalid reset token.");
        try { return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(raw.getBytes(StandardCharsets.US_ASCII))); }
        catch(NoSuchAlgorithmException impossible) { throw new IllegalStateException(impossible); }
    }
    public static boolean usable(Instant expiresAt, Instant usedAt, Instant now) { return usedAt==null && expiresAt!=null && expiresAt.isAfter(now); }
}
