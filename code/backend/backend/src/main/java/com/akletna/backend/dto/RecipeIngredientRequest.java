package com.akletna.backend.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public class RecipeIngredientRequest {

    @NotNull(message = "Ingredient ID is required")
    @Positive
    private Long ingredientId;

    @NotNull(message = "Quantity is required")
    @Positive(message = "Quantity must be greater than zero")
    @jakarta.validation.constraints.Digits(integer = 12, fraction = 12)
    private java.math.BigDecimal quantity;

    @jakarta.validation.constraints.Size(max = 30)
    private String unit;
    public String getUnit() { return unit; }
    public void setUnit(String value) { unit = value; }

    public RecipeIngredientRequest() {
    }

    public RecipeIngredientRequest(Long ingredientId, java.math.BigDecimal quantity) {
        this.ingredientId = ingredientId;
        this.quantity = quantity;
    }

    public Long getIngredientId() {
        return ingredientId;
    }

    public void setIngredientId(Long ingredientId) {
        this.ingredientId = ingredientId;
    }

    public java.math.BigDecimal getQuantity() {
        return quantity;
    }

    public void setQuantity(java.math.BigDecimal quantity) {
        this.quantity = quantity;
    }
}
