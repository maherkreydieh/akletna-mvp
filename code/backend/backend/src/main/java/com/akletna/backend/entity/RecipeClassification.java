package com.akletna.backend.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import java.time.Instant;

/** Budget classification is a reviewed editorial fact, not a price estimate. */
@Entity @Table(name="recipe_classifications")
public class RecipeClassification implements org.springframework.data.domain.Persistable<Long> {
    @Transient private boolean newRow=true;
    @Override public Long getId() { return recipeId; }
    @Override public boolean isNew() { return newRow; }
    @PostLoad @PostPersist void markPersisted() { newRow=false; }
    @Id private Long recipeId;
    @MapsId @OneToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="recipe_id")
    @OnDelete(action=OnDeleteAction.CASCADE)
    private Recipe recipe;
    @Column(nullable=false) private boolean budgetFriendly;
    @Column(nullable=false) private Instant reviewedAt;
    public Long getRecipeId() { return recipeId; }
    public void setRecipe(Recipe value) { recipe=value;recipeId=value.getId(); }
    public boolean isBudgetFriendly() { return budgetFriendly; }
    public void setBudgetFriendly(boolean value) { budgetFriendly=value; }
    public Instant getReviewedAt() { return reviewedAt; }
    public void setReviewedAt(Instant value) { reviewedAt=value; }
}
