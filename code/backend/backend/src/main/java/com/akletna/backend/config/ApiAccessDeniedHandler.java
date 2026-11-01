package com.akletna.backend.config;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.web.access.AccessDeniedHandler;
import org.springframework.stereotype.Component;
import tools.jackson.databind.json.JsonMapper;

import java.io.IOException;
import java.time.Instant;
import java.util.Map;

@Component
public class ApiAccessDeniedHandler implements AccessDeniedHandler {
    private final JsonMapper mapper = JsonMapper.builder().build();

    @Override
    public void handle(HttpServletRequest request, HttpServletResponse response,
                       AccessDeniedException exception) throws IOException {
        // Write the response directly: sendError would dispatch to protected /error.
        response.setStatus(HttpStatus.FORBIDDEN.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.getWriter().write(mapper.writeValueAsString(Map.of(
                "timestamp", Instant.now().toString(), "status", 403,
                "error", "Forbidden", "message", "Access denied.", "path", request.getRequestURI())));
    }
}
