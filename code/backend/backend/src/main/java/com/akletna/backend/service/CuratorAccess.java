package com.akletna.backend.service;
import com.akletna.backend.exception.UnauthorizedResourceException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
public final class CuratorAccess {
    private CuratorAccess() {}
    public static void require(String configured,String supplied) {
        if(configured==null || configured.length()<32 || supplied==null ||
                !MessageDigest.isEqual(configured.getBytes(StandardCharsets.UTF_8),supplied.getBytes(StandardCharsets.UTF_8)))
            throw new UnauthorizedResourceException("Curation access denied.");
    }
}
