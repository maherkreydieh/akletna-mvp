package com.akletna.backend.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "recipe_ingredients", uniqueConstraints = @UniqueConstraint(name = "uq_recipe_ingredient", columnNames = {"recipe_id", "ingredient_id"}))
public class RecipeIngredient {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY) // Automatically tracks line item IDs (1, 2, 3...)
    private Long id;

    @ManyToOne
    @JoinColumn(name = "recipe_id", nullable = false) // Links this row to a specific recipe
    private Recipe recipe;

    @ManyToOne
    @JoinColumn(name = "ingredient_id", nullable = false) // Links this row to a specific ingredient
    private Ingredient ingredient;

    @Column(nullable = false, precision = 24, scale = 12)
    private java.math.BigDecimal quantity; // Allows decimals (e.g., 1.5 cups or 500 grams)

    @Column(length = 30)
    private String unit;
    public String getUnit() { return unit; }
    public void setUnit(String value) { unit = value; }

    // --- Standard Constructor (Required by JPA) ---
    public RecipeIngredient() {
    }

    // --- Getters and Setters ---
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Recipe getRecipe() {
        return recipe;
    }

    public void setRecipe(Recipe recipe) {
        this.recipe = recipe;
    }

    public Ingredient getIngredient() {
        return ingredient;
    }

    public void setIngredient(Ingredient ingredient) {
        this.ingredient = ingredient;
    }

    public java.math.BigDecimal getQuantity() {
        return quantity;
    }

    public void setQuantity(java.math.BigDecimal quantity) {
        this.quantity = quantity;
    }
}
