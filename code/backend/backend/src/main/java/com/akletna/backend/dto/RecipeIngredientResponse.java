package com.akletna.backend.dto;

public class RecipeIngredientResponse {

    private Long id;
    private Long recipeId;
    private Long ingredientId;
    private String ingredientName;
    private String unit;
    private java.math.BigDecimal quantity;

    public RecipeIngredientResponse() {
    }

    public RecipeIngredientResponse(Long id, Long recipeId, Long ingredientId, String ingredientName, String unit, java.math.BigDecimal quantity) {
        this.id = id;
        this.recipeId = recipeId;
        this.ingredientId = ingredientId;
        this.ingredientName = ingredientName;
        this.unit = unit;
        this.quantity = quantity;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getRecipeId() {
        return recipeId;
    }

    public void setRecipeId(Long recipeId) {
        this.recipeId = recipeId;
    }

    public Long getIngredientId() {
        return ingredientId;
    }

    public void setIngredientId(Long ingredientId) {
        this.ingredientId = ingredientId;
    }

    public String getIngredientName() {
        return ingredientName;
    }

    public void setIngredientName(String ingredientName) {
        this.ingredientName = ingredientName;
    }

    public String getUnit() {
        return unit;
    }

    public void setUnit(String unit) {
        this.unit = unit;
    }

    public java.math.BigDecimal getQuantity() {
        return quantity;
    }

    public void setQuantity(java.math.BigDecimal quantity) {
        this.quantity = quantity;
    }
}