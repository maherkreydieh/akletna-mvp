package com.akletna.backend.config;

import com.akletna.backend.service.JwtService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.List;
import java.util.Optional;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    private final JwtService jwtService;
    private final JwtAuthenticationEntryPoint entryPoint;
    private final com.akletna.backend.repository.UserRepository users;
    public JwtAuthenticationFilter(JwtService jwtService, JwtAuthenticationEntryPoint entryPoint,
                                   com.akletna.backend.repository.UserRepository users) {
        this.jwtService = jwtService;
        this.entryPoint = entryPoint;
        this.users = users;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header == null) {
            filterChain.doFilter(request, response);
            return;
        }

        Optional<String> email = (header.regionMatches(true, 0, "Bearer ", 0, 7)
                ? jwtService.validateIdentity(header.substring(7)) : Optional.<JwtService.Identity>empty())
                .flatMap(identity -> users.findByEmail(identity.email())
                        .filter(user -> user.getId() != null && user.getId() == identity.userId())
                        .filter(user -> jwtService.matchesCredentials(identity,user))
                        .map(com.akletna.backend.entity.User::getEmail));
        if (email.isEmpty()) {
            SecurityContextHolder.clearContext();
            entryPoint.commence(request, response, new BadCredentialsException("Invalid authentication"));
            return;
        }

        if (SecurityContextHolder.getContext().getAuthentication() == null) {
            var authentication = new UsernamePasswordAuthenticationToken(
                    email.get(), null, List.of(new SimpleGrantedAuthority("ROLE_USER")));
            authentication.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
            SecurityContextHolder.getContext().setAuthentication(authentication);
        }
        filterChain.doFilter(request, response);
    }
}
