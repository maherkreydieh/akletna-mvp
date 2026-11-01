package com.akletna.backend.security;

import java.time.*;
import java.util.*;

/** Bounded single-node limiter groundwork. Use a shared gateway limit before multi-node rollout. */
public final class AuthAttemptLimiter {
    private final Map<String,Window> windows=new HashMap<>();
    private record Window(Instant end,int attempts) {}
    public synchronized boolean allow(String opaqueKey, Instant now) {
        windows.entrySet().removeIf(entry -> !entry.getValue().end().isAfter(now));
        Window current=windows.get(opaqueKey);
        if(current==null) {
            if(windows.size()>=10_000) return false;
            windows.put(opaqueKey,new Window(now.plus(Duration.ofMinutes(15)),1)); return true;
        }
        if(current.attempts()>=5) return false;
        windows.put(opaqueKey,new Window(current.end(),current.attempts()+1)); return true;
    }
}
