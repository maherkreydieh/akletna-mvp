package com.akletna.backend.entity;

import com.akletna.backend.exception.BadRequestException;
import jakarta.persistence.*;
import java.time.LocalDateTime;
import java.util.*;

/** Immutable recipe values embedded in the plan; replacement creates a new value. */
@Embeddable
public class MealPlanSnapshot {
    @Column(name="snapshot_state", columnDefinition="varchar(20) default 'PENDING'")
    private String state;
    @Column(name="snapshot_name") private String name;
    @Column(name="snapshot_category") private String category;
    @Column(name="snapshot_image_url") private String imageUrl;
    @Column(name="snapshot_base_servings") private Integer baseServings;
    @Column(name="snapshot_captured_at") private LocalDateTime capturedAt;
    @ElementCollection
    @CollectionTable(name="meal_plan_ingredient_snapshots", joinColumns=@JoinColumn(name="meal_plan_id"))
    @OrderColumn(name="line_index")
    private List<MealPlanIngredientSnapshot> ingredients = new ArrayList<>();

    protected MealPlanSnapshot() {}
    public static MealPlanSnapshot capture(Recipe recipe) {
        if (recipe.getServings()==null || recipe.getServings()<=0 || recipe.getName()==null || recipe.getName().isBlank())
            throw new BadRequestException("This recipe cannot be planned until its name and base servings are valid.");
        var result = new MealPlanSnapshot();
        result.name=recipe.getName(); result.category=recipe.getCategory(); result.imageUrl=recipe.getImageUrl();
        result.baseServings=recipe.getServings(); result.capturedAt=LocalDateTime.now();
        for (var line : recipe.getIngredients()) {
            var ingredient=line.getIngredient();
            if (ingredient==null || ingredient.getId()==null || ingredient.getName()==null || ingredient.getName().isBlank()
                    || line.getQuantity()==null || line.getQuantity().signum()<=0
                    || line.getQuantity().stripTrailingZeros().scale()>12
                    || line.getQuantity().abs().compareTo(new java.math.BigDecimal("1000000000000"))>=0
                    || (line.getUnit()!=null && line.getUnit().length()>30))
                throw new BadRequestException("This recipe contains an invalid ingredient and cannot be planned.");
            result.ingredients.add(new MealPlanIngredientSnapshot(ingredient.getId(), ingredient.getName(), line.getQuantity(), line.getUnit()));
        }
        result.state="READY";
        return result;
    }
    public boolean isReady() { return "READY".equals(state); }
    public String getState() { return state; }
    public String getName() { return name; }
    public String getCategory() { return category; }
    public String getImageUrl() { return imageUrl; }
    public Integer getBaseServings() { return baseServings; }
    public LocalDateTime getCapturedAt() { return capturedAt; }
    public List<MealPlanIngredientSnapshot> getIngredients() { return Collections.unmodifiableList(ingredients); }
}
