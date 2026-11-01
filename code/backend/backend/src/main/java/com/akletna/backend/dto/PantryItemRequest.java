package com.akletna.backend.dto;
import jakarta.validation.constraints.*;

public class PantryItemRequest extends PantryQuantityRequest {
    @NotNull(message="Ingredient ID is required.") @Positive
    private Long ingredientId;
    public Long getIngredientId() { return ingredientId; }
    public void setIngredientId(Long value) { ingredientId=value; }
}
