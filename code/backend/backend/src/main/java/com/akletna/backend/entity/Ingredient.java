package com.akletna.backend.entity;

import jakarta.persistence.*;

import java.util.List;

@Entity
@Table(name = "ingredients") // Avoids any database conflicts and plurals naming convention
public class Ingredient {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY) // Automatically tracks and auto-increments IDs (1, 2, 3...)
    private Long id;

    @Column(nullable = false) // Ensures name cannot be left blank
    private String name;

    private String unit; // Measurement unit (e.g., g, cup, piece, tbsp)
    // Trusted external identity; ordinary ingredient requests cannot set it.
    @Column(length = 30)
    private String nutritionProvider;
    @Column(length = 100)
    private String externalFoodId;
    @Column(length = 100)
    private String preparationState;

    public String getNutritionProvider() { return nutritionProvider; }
    public void setNutritionProvider(String value) { nutritionProvider = value; }
    public String getExternalFoodId() { return externalFoodId; }
    public void setExternalFoodId(String value) { externalFoodId = value; }
    public String getPreparationState() { return preparationState; }
    public void setPreparationState(String value) { preparationState = value; }

    @OneToMany(mappedBy = "ingredient")
    private List<RecipeIngredient> recipeIngredients;

    // --- Standard Constructor (Required by JPA) ---
    public Ingredient() {
    }

    // --- Getters and Setters ---
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getUnit() {
        return unit;
    }

    public void setUnit(String unit) {
        this.unit = unit;
    }

    public List<RecipeIngredient> getRecipeIngredients() {
        return recipeIngredients;
    }

    public void setRecipeIngredients(List<RecipeIngredient> recipeIngredients) {
        this.recipeIngredients = recipeIngredients;
    }

}
