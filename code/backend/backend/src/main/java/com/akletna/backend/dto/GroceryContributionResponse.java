package com.akletna.backend.dto;

import java.time.LocalDateTime;
import java.util.List;

public record GroceryContributionResponse(Long id,String source,String sourceName,Long recipeId,Integer servings,
        LocalDateTime createdAt,List<RecipeShortageResponse.Line> ingredients) {}
