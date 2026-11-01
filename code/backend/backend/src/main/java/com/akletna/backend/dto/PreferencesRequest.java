package com.akletna.backend.dto;

import java.util.Set;
import com.akletna.backend.entity.MealGoal;

public class PreferencesRequest {

    @jakarta.validation.constraints.Size(max=50)
    private Set<@jakarta.validation.constraints.NotBlank @jakarta.validation.constraints.Size(max=255) String> preferredCategories;
    @jakarta.validation.constraints.Size(max=50)
    private Set<String> allergies;
    @jakarta.validation.constraints.Size(max=50)
    private Set<String> dietaryRestrictions;
    @jakarta.validation.constraints.Size(max=50)
    private Set<String> dislikedIngredients;
    @jakarta.validation.constraints.Size(max=50)
    private Set<@jakarta.validation.constraints.NotNull @jakarta.validation.constraints.Positive Long> dislikedIngredientIds;
    @jakarta.validation.constraints.Size(max=10)
    private Set<@jakarta.validation.constraints.NotNull MealGoal> preferredMealGoals;
    public Set<Long> getDislikedIngredientIds() { return dislikedIngredientIds; }
    public void setDislikedIngredientIds(Set<Long> value) { dislikedIngredientIds=value; }
    public Set<com.akletna.backend.entity.MealGoal> getPreferredMealGoals() { return preferredMealGoals; }
    public void setPreferredMealGoals(Set<com.akletna.backend.entity.MealGoal> value) { preferredMealGoals=value; }

    public PreferencesRequest() {
    }

    public PreferencesRequest(Set<String> preferredCategories, Set<String> allergies,
                              Set<String> dietaryRestrictions, Set<String> dislikedIngredients) {
        this.preferredCategories = preferredCategories;
        this.allergies = allergies;
        this.dietaryRestrictions = dietaryRestrictions;
        this.dislikedIngredients = dislikedIngredients;
    }

    public Set<String> getPreferredCategories() {
        return preferredCategories;
    }

    public void setPreferredCategories(Set<String> preferredCategories) {
        this.preferredCategories = preferredCategories;
    }

    public Set<String> getAllergies() {
        return allergies;
    }

    public void setAllergies(Set<String> allergies) {
        this.allergies = allergies;
    }

    public Set<String> getDietaryRestrictions() {
        return dietaryRestrictions;
    }

    public void setDietaryRestrictions(Set<String> dietaryRestrictions) {
        this.dietaryRestrictions = dietaryRestrictions;
    }

    public Set<String> getDislikedIngredients() {
        return dislikedIngredients;
    }

    public void setDislikedIngredients(Set<String> dislikedIngredients) {
        this.dislikedIngredients = dislikedIngredients;
    }
}
