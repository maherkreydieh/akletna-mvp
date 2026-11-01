package com.akletna.backend.dto;

import java.util.List;

public record RecipeShortageResponse(Long recipeId,String recipeName,Integer servings,boolean pantryEmpty,
        String status,Long contributionId,List<Line> ingredients) {
    public record Line(Long ingredientId,String ingredientName,String status,String quantity,String unit) {}
}
