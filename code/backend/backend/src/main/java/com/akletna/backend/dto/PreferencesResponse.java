package com.akletna.backend.dto;

import java.util.Set;

public class PreferencesResponse {

    private Long id;
    private Set<String> preferredCategories;
    private Set<String> allergies;
    private Set<String> dietaryRestrictions;
    private Set<String> dislikedIngredients;
    private Set<Long> dislikedIngredientIds=Set.of();
    private Set<com.akletna.backend.entity.MealGoal> preferredMealGoals=Set.of();
    private Set<String> legacyAllergies=Set.of();
    private Set<String> legacyDietaryRestrictions=Set.of();
    public Set<Long> getDislikedIngredientIds() { return dislikedIngredientIds; }
    public void setDislikedIngredientIds(Set<Long> value) { dislikedIngredientIds=value; }
    public Set<com.akletna.backend.entity.MealGoal> getPreferredMealGoals() { return preferredMealGoals; }
    public void setPreferredMealGoals(Set<com.akletna.backend.entity.MealGoal> value) { preferredMealGoals=value; }
    public Set<String> getLegacyAllergies() { return legacyAllergies; }
    public void setLegacyAllergies(Set<String> value) { legacyAllergies=value; }
    public Set<String> getLegacyDietaryRestrictions() { return legacyDietaryRestrictions; }
    public void setLegacyDietaryRestrictions(Set<String> value) { legacyDietaryRestrictions=value; }

    public PreferencesResponse() {
    }

    public PreferencesResponse(Long id, Set<String> preferredCategories, Set<String> allergies,
                               Set<String> dietaryRestrictions, Set<String> dislikedIngredients) {
        this.id = id;
        this.preferredCategories = preferredCategories;
        this.allergies = allergies;
        this.dietaryRestrictions = dietaryRestrictions;
        this.dislikedIngredients = dislikedIngredients;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
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
