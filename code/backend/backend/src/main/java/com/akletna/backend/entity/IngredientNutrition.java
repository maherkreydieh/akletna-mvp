package com.akletna.backend.entity;

import jakarta.persistence.*;
import com.akletna.backend.nutrition.Nutrients;
import java.math.BigDecimal;
import java.time.Instant;

/** Last successfully reviewed profile. Failed refreshes leave this snapshot intact. */
@Entity
@Table(name = "ingredient_nutrition")
public class IngredientNutrition implements org.springframework.data.domain.Persistable<Long> {
    @Id private Long ingredientId;
    @OneToOne @MapsId @JoinColumn(name = "ingredient_id") private Ingredient ingredient;
    // An assigned shared ID does not mean a new snapshot is already persisted.
    // Ensure Spring Data uses persist rather than merging a nonexistent profile.
    @Transient private boolean newProfile = true;
    @Override public Long getId() { return ingredientId; }
    @Override public boolean isNew() { return newProfile; }
    @PostLoad @PostPersist
    void markPersisted() { newProfile = false; }
    @Column(nullable = false, length = 30) private String provider;
    @Column(nullable = false, length = 100) private String externalFoodId;
    @Column(nullable = false, length = 100) private String preparationState;
    @Column(nullable = false, length = 1000) private String description;
    @Column(nullable = false, length = 30) private String dataType;
    @Column(nullable = false) private Instant fetchedAt;
    @Column(nullable = false, precision = 24, scale = 12) private BigDecimal caloriesKcal;
    @Column(nullable = false, precision = 24, scale = 12) private BigDecimal proteinGrams;
    @Column(nullable = false, precision = 24, scale = 12) private BigDecimal carbohydratesGrams;
    @Column(nullable = false, precision = 24, scale = 12) private BigDecimal fatGrams;
    public IngredientNutrition() { }
    public IngredientNutrition(Ingredient ingredient, com.akletna.backend.nutrition.UsdaFoodClient.Profile profile, String state) {
        this.ingredient = ingredient; this.ingredientId = ingredient.getId();
        updateProfile(profile, state);
    }
    public void updateProfile(com.akletna.backend.nutrition.UsdaFoodClient.Profile profile, String state) {
        provider = profile.food().provider(); externalFoodId = profile.food().externalFoodId();
        description = profile.food().description(); dataType = profile.food().dataType();
        preparationState = state; fetchedAt = Instant.now();
        var n = profile.nutrients(); caloriesKcal = n.caloriesKcal(); proteinGrams = n.proteinGrams();
        carbohydratesGrams = n.carbohydratesGrams(); fatGrams = n.fatGrams();
    }
    public String getProvider() { return provider; }
    public String getExternalFoodId() { return externalFoodId; }
    public String getPreparationState() { return preparationState; }
    public String getDescription() { return description; }
    public String getDataType() { return dataType; }
    public Instant getFetchedAt() { return fetchedAt; }
    public Nutrients nutrients() { return new Nutrients(caloriesKcal, proteinGrams, carbohydratesGrams, fatGrams); }
}
