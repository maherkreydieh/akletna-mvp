package com.akletna.backend.service;

import com.akletna.backend.entity.User;
import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.JwtParser;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.SecretKey;
import java.util.Date;
import java.util.Optional;

@Service
public class JwtService {
    private final SecretKey signingKey;
    private final JwtParser parser;
    private final long jwtExpiration;

    public JwtService(@Value("${akletna.jwt.secret}") String secret,
                      @Value("${akletna.jwt.expiration}") long jwtExpiration) {
        // Configuration errors fail at startup, not as bad-token errors.
        this.signingKey = Keys.hmacShaKeyFor(Decoders.BASE64.decode(secret));
        this.parser = Jwts.parser().verifyWith(signingKey).build();
        if (jwtExpiration <= 0) {
            throw new IllegalArgumentException("JWT expiration must be positive");
        }
        this.jwtExpiration = jwtExpiration;
    }

    public String generateToken(User user) {
        return Jwts.builder()
                .claim("userId", user.getId())
                .claim("credentials", credentialStamp(user))
                .subject(user.getEmail())
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + jwtExpiration))
                .signWith(signingKey)
                .compact();
    }

    /** Signature, expiry, and required claims are checked in a single parse. */
    public Optional<String> validateAndExtractEmail(String token) {
        return validateIdentity(token).map(Identity::email);
    }

    public record Identity(String email, long userId, String credentials) {}

    /** HMAC of the stored credential, never the password hash itself in the JWT. */
    private String credentialStamp(User user) {
        try {
            var mac=javax.crypto.Mac.getInstance("HmacSHA256");
            mac.init(new javax.crypto.spec.SecretKeySpec(signingKey.getEncoded(),"HmacSHA256"));
            return java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(mac.doFinal(
                (user.getId()+":"+java.util.Objects.toString(user.getPassword(),"")).getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        } catch(java.security.GeneralSecurityException impossible) { throw new IllegalStateException(impossible); }
    }

    public boolean matchesCredentials(Identity identity,User user) {
        return identity.credentials()==null || java.security.MessageDigest.isEqual(
            identity.credentials().getBytes(java.nio.charset.StandardCharsets.US_ASCII),
            credentialStamp(user).getBytes(java.nio.charset.StandardCharsets.US_ASCII));
    }

    public Optional<Identity> validateIdentity(String token) {
        try {
            Claims claims = parser.parseSignedClaims(token).getPayload();
            String email = claims.getSubject();
            Date expiration = claims.getExpiration();
            Object id = claims.get("userId");
            if (!(id instanceof Integer || id instanceof Long) || ((Number) id).longValue() <= 0
                    || email == null || email.isBlank() || expiration == null || !expiration.after(new Date())) {
                return Optional.empty();
            }
            return Optional.of(new Identity(email, ((Number) id).longValue(), claims.get("credentials",String.class)));
        } catch (JwtException | IllegalArgumentException e) {
            // No token contents or parser details are logged or returned.
            return Optional.empty();
        }
    }
}
