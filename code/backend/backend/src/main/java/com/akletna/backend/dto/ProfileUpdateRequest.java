package com.akletna.backend.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ProfileUpdateRequest(@NotNull @Size(max=100) String name) {}
