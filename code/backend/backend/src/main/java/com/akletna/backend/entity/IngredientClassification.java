package com.akletna.backend.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import java.time.Instant;
import java.util.HashSet;
import java.util.Set;

/** Curator-reviewed positive facts; completeness is explicit, never inferred from names. */
@Entity @Table(name="ingredient_classifications")
public class IngredientClassification implements org.springframework.data.domain.Persistable<Long> {
    @Transient private boolean newRow=true;
    @Override public Long getId() { return ingredientId; }
    @Override public boolean isNew() { return newRow; }
    @PostLoad @PostPersist void markPersisted() { newRow=false; }
    @Id private Long ingredientId;
    @MapsId @OneToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="ingredient_id")
    @OnDelete(action=OnDeleteAction.CASCADE)
    private Ingredient ingredient;
    @ElementCollection
    @CollectionTable(name="ingredient_allergens",joinColumns=@JoinColumn(name="ingredient_id"))
    @Enumerated(EnumType.STRING) @Column(name="allergen",nullable=false,length=30)
    private Set<Allergen> allergens=new HashSet<>();
    @Column(nullable=false) private boolean allergensComplete;
    @Enumerated(EnumType.STRING) @Column(nullable=false,length=20)
    private CompatibilityStatus vegetarian=CompatibilityStatus.UNKNOWN;
    @Enumerated(EnumType.STRING) @Column(nullable=false,length=20)
    private CompatibilityStatus vegan=CompatibilityStatus.UNKNOWN;
    @Column(nullable=false) private Instant reviewedAt;
    public Long getIngredientId() { return ingredientId; }
    public void setIngredient(Ingredient value) { ingredient=value; ingredientId=value.getId(); }
    public Set<Allergen> getAllergens() { return allergens; }
    public void setAllergens(Set<Allergen> value) { allergens=new HashSet<>(value); }
    public boolean isAllergensComplete() { return allergensComplete; }
    public void setAllergensComplete(boolean value) { allergensComplete=value; }
    public CompatibilityStatus getVegetarian() { return vegetarian; }
    public void setVegetarian(CompatibilityStatus value) { vegetarian=value; }
    public CompatibilityStatus getVegan() { return vegan; }
    public void setVegan(CompatibilityStatus value) { vegan=value; }
    public Instant getReviewedAt() { return reviewedAt; }
    public void setReviewedAt(Instant value) { reviewedAt=value; }
}
