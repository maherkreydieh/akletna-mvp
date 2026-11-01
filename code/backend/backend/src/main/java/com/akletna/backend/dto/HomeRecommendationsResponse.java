package com.akletna.backend.dto;

import java.util.List;

/** Home-specific selection context; leaves the existing discovery response intact. */
public record HomeRecommendationsResponse(boolean preferencesConfigured,
        List<String> limitations, RecommendationsResponse selection) {}
