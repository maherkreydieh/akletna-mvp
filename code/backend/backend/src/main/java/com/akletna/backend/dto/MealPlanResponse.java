package com.akletna.backend.dto;

import com.akletna.backend.entity.MealType;

import java.time.LocalDate;
import java.time.LocalDateTime;

public class MealPlanResponse {
    private String snapshotState;
    private Integer recipeBaseServings;
    private String recipeImageUrl;
    public String getSnapshotState() { return snapshotState; }
    public void setSnapshotState(String value) { snapshotState=value; }
    public Integer getRecipeBaseServings() { return recipeBaseServings; }
    public void setRecipeBaseServings(Integer value) { recipeBaseServings=value; }
    public String getRecipeImageUrl() { return recipeImageUrl; }
    public void setRecipeImageUrl(String value) { recipeImageUrl=value; }
    private Integer plannedServings;
    public Integer getPlannedServings() { return plannedServings; }
    public void setPlannedServings(Integer plannedServings) { this.plannedServings = plannedServings; }

    private Long id;
    private Long recipeId;
    private String recipeName;
    private String recipeCategory;
    private LocalDate date;
    private MealType mealType;
    private LocalDateTime createdAt;

    public MealPlanResponse() {
    }

    public MealPlanResponse(Long id, Long recipeId, String recipeName, String recipeCategory,
                            LocalDate date, MealType mealType, LocalDateTime createdAt) {
        this.id = id;
        this.recipeId = recipeId;
        this.recipeName = recipeName;
        this.recipeCategory = recipeCategory;
        this.date = date;
        this.mealType = mealType;
        this.createdAt = createdAt;
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

    public String getRecipeName() {
        return recipeName;
    }

    public void setRecipeName(String recipeName) {
        this.recipeName = recipeName;
    }

    public String getRecipeCategory() {
        return recipeCategory;
    }

    public void setRecipeCategory(String recipeCategory) {
        this.recipeCategory = recipeCategory;
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

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }
}
