package com.akletna.backend.dto;

import java.time.LocalDateTime;
import com.akletna.backend.entity.RecipeOrigin;
import com.akletna.backend.entity.RecipeVisibility;

public class RecipeResponse {
    private RecipeEvaluationResponse evaluation;
    public RecipeEvaluationResponse getEvaluation() { return evaluation; }
    public void setEvaluation(RecipeEvaluationResponse value) { evaluation=value; }
    // Viewer-specific state is populated on detail and saved-library responses.
    private Boolean saved;
    private Long saveCount;
    private java.time.Instant savedAt;
    public Boolean getSaved() { return saved; }
    public void setSaved(boolean saved) { this.saved = saved; }
    public Long getSaveCount() { return saveCount; }
    public void setSaveCount(Long saveCount) { this.saveCount = saveCount; }
    public java.time.Instant getSavedAt() { return savedAt; }
    public void setSavedAt(java.time.Instant savedAt) { this.savedAt = savedAt; }
    private RecipeOrigin origin;
    private RecipeVisibility visibility;

    public RecipeOrigin getOrigin() { return origin; }
    public void setOrigin(RecipeOrigin origin) { this.origin = origin; }
    public RecipeVisibility getVisibility() { return visibility; }
    public void setVisibility(RecipeVisibility visibility) { this.visibility = visibility; }
    private Long id;
    private String name;
    private String description;
    private String instructions;
    private Integer servings;
    private Integer cookingTime;
    private String category;
    private String imageUrl;
    private LocalDateTime createdAt;
    private Long userId;
    private String userName;

    public RecipeResponse() {
    }

    public RecipeResponse(Long id, String name, String description, String instructions,
                          Integer servings, Integer cookingTime, String category,
                          String imageUrl, LocalDateTime createdAt, Long userId, String userName) {
        this.id = id;
        this.name = name;
        this.description = description;
        this.instructions = instructions;
        this.servings = servings;
        this.cookingTime = cookingTime;
        this.category = category;
        this.imageUrl = imageUrl;
        this.createdAt = createdAt;
        this.userId = userId;
        this.userName = userName;
    }

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

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public Long getUserId() {
        return userId;
    }

    public void setUserId(Long userId) {
        this.userId = userId;
    }

    public String getUserName() {
        return userName;
    }

    public void setUserName(String userName) {
        this.userName = userName;
    }
}
