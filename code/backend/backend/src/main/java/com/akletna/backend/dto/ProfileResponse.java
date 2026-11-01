package com.akletna.backend.dto;

/** Only returned to the authenticated owner. */
public record ProfileResponse(Long id, String name, String email) {}
