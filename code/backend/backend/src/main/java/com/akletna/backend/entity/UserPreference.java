package com.akletna.backend.entity;

import jakarta.persistence.*;

import java.util.HashSet;
import java.util.Set;

@Entity
@Table(name = "user_preferences")
public class UserPreference {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @ElementCollection
    @CollectionTable(name = "user_preferred_categories", joinColumns = @JoinColumn(name = "preference_id"))
    @Column(name = "category")
    private Set<String> preferredCategories = new HashSet<>();

    @ElementCollection
    @CollectionTable(name = "user_allergies", joinColumns = @JoinColumn(name = "preference_id"))
    @Column(name = "allergy")
    private Set<String> allergies = new HashSet<>();

    @ElementCollection
    @CollectionTable(name = "user_dietary_restrictions", joinColumns = @JoinColumn(name = "preference_id"))
    @Column(name = "restriction")
    private Set<String> dietaryRestrictions = new HashSet<>();

    @ElementCollection
    @CollectionTable(name = "user_disliked_ingredients", joinColumns = @JoinColumn(name = "preference_id"))
    @Column(name = "ingredient_name")
    private Set<String> dislikedIngredients = new HashSet<>();

    @ManyToMany
    @JoinTable(name="user_disliked_ingredient_refs",joinColumns=@JoinColumn(name="preference_id"),
            inverseJoinColumns=@JoinColumn(name="ingredient_id"),
            uniqueConstraints=@UniqueConstraint(columnNames={"preference_id","ingredient_id"}))
    private Set<Ingredient> dislikedIngredientRefs=new HashSet<>();
    @ElementCollection
    @CollectionTable(name="user_preferred_meal_goals",joinColumns=@JoinColumn(name="preference_id"))
    @Enumerated(EnumType.STRING) @Column(name="meal_goal",nullable=false,length=30)
    private Set<MealGoal> preferredMealGoals=new HashSet<>();
    public Set<Ingredient> getDislikedIngredientRefs() { return dislikedIngredientRefs; }
    public void setDislikedIngredientRefs(Set<Ingredient> value) { dislikedIngredientRefs=value; }
    public Set<MealGoal> getPreferredMealGoals() { return preferredMealGoals; }
    public void setPreferredMealGoals(Set<MealGoal> value) { preferredMealGoals=value; }

    public UserPreference() {
    }

    public UserPreference(User user) {
        this.user = user;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public User getUser() {
        return user;
    }

    public void setUser(User user) {
        this.user = user;
    }

    public Set<String> getPreferredCategories() {
        return preferredCategories;
    }

    public void setPreferredCategories(Set<String> preferredCategories) {
        this.preferredCategories = preferredCategories != null ? preferredCategories : new HashSet<>();
    }

    public Set<String> getAllergies() {
        return allergies;
    }

    public void setAllergies(Set<String> allergies) {
        this.allergies = allergies != null ? allergies : new HashSet<>();
    }

    public Set<String> getDietaryRestrictions() {
        return dietaryRestrictions;
    }

    public void setDietaryRestrictions(Set<String> dietaryRestrictions) {
        this.dietaryRestrictions = dietaryRestrictions != null ? dietaryRestrictions : new HashSet<>();
    }

    public Set<String> getDislikedIngredients() {
        return dislikedIngredients;
    }

    public void setDislikedIngredients(Set<String> dislikedIngredients) {
        this.dislikedIngredients = dislikedIngredients != null ? dislikedIngredients : new HashSet<>();
    }
}
