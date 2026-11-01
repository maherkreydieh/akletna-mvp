package com.akletna.backend.service;

import com.akletna.backend.dto.RecipeNutritionResponse;
import com.akletna.backend.dto.RecipeNutritionResponse.Issue;
import com.akletna.backend.dto.RecipeNutritionResponse.Status;
import com.akletna.backend.nutrition.*;
import com.akletna.backend.repository.RecipeIngredientRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
import java.util.ArrayList;

@Service
public class RecipeNutritionService {
    private final RecipeService recipes;
    private final RecipeIngredientRepository lines;
    private final NutritionProvider provider;

    public RecipeNutritionService(RecipeService recipes, RecipeIngredientRepository lines, NutritionProvider provider) {
        this.recipes = recipes;
        this.lines = lines;
        this.provider = provider;
    }

    @Transactional(readOnly = true)
    public RecipeNutritionResponse getNutrition(Long recipeId, String email) {
        var recipe = recipes.getRecipeEntityAndVerifyReadable(recipeId, email);
        var ingredients = lines.findByRecipeId(recipeId);
        return calculate(recipe,ingredients,provider);
    }

    /** Same authoritative calculation for bulk discovery; the supplied provider is stored data only. */
    public static RecipeNutritionResponse calculate(com.akletna.backend.entity.Recipe recipe,
            java.util.List<com.akletna.backend.entity.RecipeIngredient> ingredients,NutritionProvider provider) {
        var issues = new ArrayList<Issue>();
        if (recipe.getServings() == null || recipe.getServings() <= 0) issues.add(new Issue(null, "INVALID_SERVINGS"));
        if (ingredients.isEmpty()) issues.add(new Issue(null, "NO_INGREDIENTS"));
        Nutrients total = null;
        // Request-local only: reuse identical reviewed identities without cross-user caching.
        var snapshots = new java.util.HashMap<FoodIdentity, java.util.Optional<Nutrients>>();
        for (var line : ingredients) {
            var grams = grams(line.getQuantity(), line.getUnit());
            if (grams == null) {
                issues.add(new Issue(line.getId(), "UNSUPPORTED_QUANTITY_OR_UNIT"));
                continue;
            }
            var ingredient = line.getIngredient();
            if (ingredient == null) {
                issues.add(new Issue(line.getId(), "MISSING_INGREDIENT"));
                continue;
            }
            if (blank(ingredient.getNutritionProvider()) || blank(ingredient.getExternalFoodId()) || blank(ingredient.getPreparationState())) {
                issues.add(new Issue(line.getId(), "MISSING_MAPPING"));
                continue;
            }
            var identity = new FoodIdentity(ingredient.getNutritionProvider(), ingredient.getExternalFoodId(), ingredient.getPreparationState());
            var nutrients = snapshots.computeIfAbsent(identity, provider::per100Grams);
            if (nutrients.isEmpty()) {
                issues.add(new Issue(line.getId(), "NUTRIENT_DATA_UNAVAILABLE"));
                continue;
            }
            var contribution = nutrients.get().multiply(grams.movePointLeft(2));
            total = total == null ? contribution : total.plus(contribution);
        }
        if (!issues.isEmpty()) {
            return new RecipeNutritionResponse(total == null ? Status.UNAVAILABLE : Status.INCOMPLETE, null, null, issues);
        }
        return new RecipeNutritionResponse(Status.COMPLETE, total, total.perServing(recipe.getServings()), java.util.List.of());
    }

    private static boolean blank(String value) { return value == null || value.isBlank(); }

    // Only known mass units. Volume/count requires reviewed food-specific weights/density.
    public static BigDecimal grams(BigDecimal quantity, String unit) {
        if (quantity == null || quantity.signum() <= 0 || unit == null) return null;
        var measurement = QuantityUnit.of(unit);
        return measurement.dimension() == QuantityUnit.Dimension.MASS ? measurement.canonicalQuantity(quantity) : null;
    }
}
