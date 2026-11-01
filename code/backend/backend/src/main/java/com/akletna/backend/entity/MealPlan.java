package com.akletna.backend.entity;

import jakarta.persistence.*;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Entity
@Table(name = "meal_plans", uniqueConstraints = @UniqueConstraint(name = "uq_meal_plan_slot", columnNames = {"user_id", "date", "meal_type"}))
@org.hibernate.annotations.Check(name = "ck_meal_plans_planned_servings_positive", constraints = "planned_servings > 0")
public class MealPlan {
    @Embedded
    private MealPlanSnapshot snapshot;
    public MealPlanSnapshot getSnapshot() { return snapshot; }
    public void captureRecipe(Recipe source) {
        MealPlanSnapshot captured = MealPlanSnapshot.capture(source);
        this.recipe = source;
        this.snapshot = captured;
    }
    // Nullable only for unresolved malformed legacy plans; API creation requires a positive value.
    private Integer plannedServings;
    public Integer getPlannedServings() { return plannedServings; }
    public void setPlannedServings(Integer plannedServings) { this.plannedServings = plannedServings; }

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "recipe_id", nullable = false)
    private Recipe recipe;

    @Column(nullable = false)
    private LocalDate date;

    @Enumerated(EnumType.STRING)
    @Column(name = "meal_type", nullable = false, length = 20)
    private MealType mealType;

    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;

    public MealPlan() {
    }

    public MealPlan(User user, Recipe recipe, LocalDate date, MealType mealType, LocalDateTime createdAt) {
        this.user = user;
        this.recipe = recipe;
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

    public User getUser() {
        return user;
    }

    public void setUser(User user) {
        this.user = user;
    }

    public Recipe getRecipe() {
        return recipe;
    }

    public void setRecipe(Recipe recipe) {
        this.recipe = recipe;
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
