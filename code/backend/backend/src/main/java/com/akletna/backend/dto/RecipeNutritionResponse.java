package com.akletna.backend.dto;

import com.akletna.backend.nutrition.Nutrients;
import java.util.List;

public record RecipeNutritionResponse(Status status, Nutrients totals, Nutrients perServing, List<Issue> issues) {
    public enum Status { COMPLETE, INCOMPLETE, UNAVAILABLE }
    public record Issue(Long recipeIngredientId, String reason) { }
}
