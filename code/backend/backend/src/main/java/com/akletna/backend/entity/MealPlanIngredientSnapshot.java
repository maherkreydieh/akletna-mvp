package com.akletna.backend.entity;

import jakarta.persistence.*;
import java.math.BigDecimal;

/** Value owned by one planned occurrence, never a live Ingredient relationship. */
@Embeddable
public class MealPlanIngredientSnapshot {
    @Column(name="ingredient_id", nullable=false)
    private Long ingredientId;
    @Column(name="ingredient_name", nullable=false)
    private String ingredientName;
    @Column(nullable=false, precision=24, scale=12)
    private BigDecimal quantity;
    @Column(length=30)
    private String unit;

    protected MealPlanIngredientSnapshot() {}
    public MealPlanIngredientSnapshot(Long id, String name, BigDecimal quantity, String unit) {
        this.ingredientId=id; this.ingredientName=name; this.quantity=quantity; this.unit=unit;
    }
    public Long getIngredientId() { return ingredientId; }
    public String getIngredientName() { return ingredientName; }
    public BigDecimal getQuantity() { return quantity; }
    public String getUnit() { return unit; }
}
