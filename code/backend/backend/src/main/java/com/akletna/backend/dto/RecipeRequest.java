package com.akletna.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.Valid;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.akletna.backend.entity.RecipeVisibility;
import java.util.List;

@JsonIgnoreProperties({"origin", "userId", "userName"})
public class RecipeRequest {

    private RecipeVisibility visibility;

    @Size(max = 100, message = "A recipe supports at most 100 ingredient lines")
    private List<@NotNull @Valid RecipeIngredientRequest> ingredients;

    public RecipeVisibility getVisibility() { return visibility; }
    public void setVisibility(RecipeVisibility visibility) { this.visibility = visibility; }
    public List<RecipeIngredientRequest> getIngredients() { return ingredients; }
    public void setIngredients(List<RecipeIngredientRequest> ingredients) { this.ingredients = ingredients; }

    @NotBlank(message = "Recipe name is required")
    @Size(min = 2, max = 150, message = "Name must be between 2 and 150 characters")
    private String name;

    @Size(max = 255)
    private String description;

    @NotBlank(message = "Instructions are required")
    @Size(max = 20000)
    private String instructions;

    @Positive(message = "Servings must be a positive number")
    @NotNull(message = "Servings are required")
    private Integer servings;

    @Positive(message = "Cooking time must be a positive number of minutes")
    private Integer cookingTime;

    @Size(max = 255)
    private String category;

    @Size(max = 255)
    private String imageUrl;

    public RecipeRequest() {
    }

    public RecipeRequest(String name, String description, String instructions, Integer servings, Integer cookingTime, String category, String imageUrl) {
        this.name = name;
        this.description = description;
        this.instructions = instructions;
        this.servings = servings;
        this.cookingTime = cookingTime;
        this.category = category;
        this.imageUrl = imageUrl;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public String getInstructions() {
        return instructions;
    }

    public void setInstructions(String instructions) {
        this.instructions = instructions;
    }

    public Integer getServings() {
        return servings;
    }

    public void setServings(Integer servings) {
        this.servings = servings;
    }

    public Integer getCookingTime() {
        return cookingTime;
    }

    public void setCookingTime(Integer cookingTime) {
        this.cookingTime = cookingTime;
    }

    public String getCategory() {
        return category;
    }

    public void setCategory(String category) {
        this.category = category;
    }

    public String getImageUrl() {
        return imageUrl;
    }

    public void setImageUrl(String imageUrl) {
        this.imageUrl = imageUrl;
    }
}
