package com.akletna.backend.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;
import java.util.List;
import java.util.ArrayList;

@Entity
@Table(name = "recipes")
public class Recipe {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String name;

    private String description;

    @Column(columnDefinition = "TEXT")
    private String instructions;

    private Integer servings;

    private Integer cookingTime;

    private String category;

    private String imageUrl;

    private LocalDateTime createdAt;

    // SQL defaults preserve legacy rows when Hibernate adds these columns.
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, columnDefinition = "varchar(20) default 'USER'")
    private RecipeOrigin origin = RecipeOrigin.USER;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, columnDefinition = "varchar(20) default 'PRIVATE'")
    private RecipeVisibility visibility = RecipeVisibility.PRIVATE;

    @ManyToOne
    @JoinColumn(name = "user_id")
    private User user;

    @OneToMany(mappedBy = "recipe", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<RecipeIngredient> ingredients = new ArrayList<>();

    public RecipeOrigin getOrigin() { return origin; }
    public void setOrigin(RecipeOrigin origin) { this.origin = origin; }
    public RecipeVisibility getVisibility() { return visibility; }
    public void setVisibility(RecipeVisibility visibility) { this.visibility = visibility; }

    public Recipe() {
    }

    // --- Getter and Setter for the User relationship ---
    public User getUser() {
        return user;
    }

    public void setUser(User user) {
        this.user = user;
    }

    // --- Generated Getters and Setters for standard fields ---
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

    public List<RecipeIngredient> getIngredients() {
        return ingredients;
    }

    public void setIngredients(List<RecipeIngredient> ingredients) {
        this.ingredients = ingredients;
    }

}
