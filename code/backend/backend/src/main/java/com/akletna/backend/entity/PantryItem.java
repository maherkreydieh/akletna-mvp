package com.akletna.backend.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.Check;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name="pantry_items", uniqueConstraints=@UniqueConstraint(name="uk_pantry_user_ingredient",columnNames={"user_id","ingredient_id"}))
@Check(name="ck_pantry_quantity_pair",constraints="(quantity IS NULL AND unit IS NULL) OR (quantity IS NOT NULL AND quantity > 0 AND unit IS NOT NULL AND length(trim(unit)) > 0)")
public class PantryItem {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="user_id",nullable=false)
    @OnDelete(action=OnDeleteAction.CASCADE)
    private User user;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="ingredient_id",nullable=false)
    private Ingredient ingredient;
    @Column(precision=27,scale=12)
    private BigDecimal quantity;
    @Column(length=30)
    private String unit;
    @Column(nullable=false)
    private Instant updatedAt;

    public Long getId() { return id; }
    public void setId(Long value) { id=value; }
    public User getUser() { return user; }
    public void setUser(User value) { user=value; }
    public Ingredient getIngredient() { return ingredient; }
    public void setIngredient(Ingredient value) { ingredient=value; }
    public BigDecimal getQuantity() { return quantity; }
    public void setQuantity(BigDecimal value) { quantity=value; }
    public String getUnit() { return unit; }
    public void setUnit(String value) { unit=value; }
    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant value) { updatedAt=value; }
}
