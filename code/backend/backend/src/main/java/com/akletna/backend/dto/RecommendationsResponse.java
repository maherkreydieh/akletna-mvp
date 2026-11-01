package com.akletna.backend.dto;

import java.math.BigDecimal;
import java.util.List;
import com.akletna.backend.dto.PantryMatchesResponse.MatchStatus;

public record RecommendationsResponse(boolean pantryEmpty, int readableRecipeCount,
        int excludedRecipeCount, List<Result> recommendations) {
    public record Reason(String code, String message, BigDecimal points) {}
    public record Result(int rank, RecipeResponse recipe, BigDecimal score,
            MatchStatus pantryStatus, BigDecimal pantryPercentage,
            List<Reason> reasons) {}
}
