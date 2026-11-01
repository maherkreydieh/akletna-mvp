package com.akletna.backend.dto;

import com.akletna.backend.entity.MealType;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public class MealPlanRequest {
    @NotNull(message = "Planned servings are required")
    @jakarta.validation.constraints.Positive(message = "Planned servings must be positive")
    private Integer plannedServings;
    public Integer getPlannedServings() { return plannedServings; }
    // Reject JSON fractions/strings instead of Jackson's default integer coercion.
    @com.fasterxml.jackson.annotation.JsonSetter("plannedServings")
    public void readPlannedServings(tools.jackson.databind.JsonNode value) {
        if (value == null || value.isNull()) { plannedServings = null; return; }
        if (!value.isIntegralNumber() || !value.canConvertToInt())
            throw new IllegalArgumentException("Planned servings must be a whole number within the integer range.");
        plannedServings = value.intValue();
    }
    @com.fasterxml.jackson.annotation.JsonIgnore
    public void setPlannedServings(Integer plannedServings) { this.plannedServings = plannedServings; }

    @NotNull(message = "Recipe ID is required")
    @jakarta.validation.constraints.Positive
    private Long recipeId;

    @NotNull(message = "Date is required (format: YYYY-MM-DD)")
    private LocalDate date;

    @NotNull(message = "Meal type is required (BREAKFAST, LUNCH, DINNER, SNACK)")
    private MealType mealType;

    public MealPlanRequest() {
    }

    public MealPlanRequest(Long recipeId, LocalDate date, MealType mealType) {
        this.recipeId = recipeId;
        this.date = date;
        this.mealType = mealType;
    }

    public Long getRecipeId() {
        return recipeId;
    }

    public void setRecipeId(Long recipeId) {
        this.recipeId = recipeId;
    }

    public LocalDate getDate() {
        return date;
    }

    public void setDate(LocalDate date) {
        this.date = date;
    }

    public MealType getMealType() {
        return mealType;
    }

    public void setMealType(MealType mealType) {
        this.mealType = mealType;
    }
}
