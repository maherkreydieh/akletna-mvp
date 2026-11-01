package com.akletna.backend.dto;

import com.akletna.backend.entity.RecipeOrigin;
import com.akletna.backend.entity.RecipeVisibility;
import java.math.BigDecimal;
import java.util.List;

public record PantryMatchesResponse(boolean pantryEmpty, int readableRecipeCount,
                                   int excludedRecipeCount, List<RecipeMatch> matches) {
    public enum IngredientStatus { ENOUGH, SHORTAGE, PRESENT_QUANTITY_UNKNOWN, PRESENT_INCOMPARABLE, MISSING }
    public enum MatchStatus { READY_TO_COOK, LIKELY_READY, ALMOST_THERE, MORE_SHOPPING_NEEDED }
    public record Amount(String quantity, String unit) {}
    public record IngredientMatch(Long ingredientId, String ingredientName, IngredientStatus status,
                                  Amount required, Amount available, Amount shortage, boolean assumedStaple) {}
    public record Counts(int enough, int shortage, int unknown, int incomparable, int missing) {}
    public record RecipeMatch(Long id, String name, RecipeOrigin origin, RecipeVisibility visibility,
                              Integer servings, Integer cookingTime, String imageUrl,
                              MatchStatus status, BigDecimal score, Counts counts,
                              List<IngredientMatch> ingredients, RecipeEvaluationResponse evaluation) {}
}
