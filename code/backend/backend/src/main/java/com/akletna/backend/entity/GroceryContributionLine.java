package com.akletna.backend.entity;

import com.akletna.backend.service.QuantityScaling;
import jakarta.persistence.*;
import java.math.BigInteger;

/** Captured amount (or explicit uncertainty), owned by one grocery addition. */
@Embeddable
public class GroceryContributionLine {
    private Long ingredientId;
    private Long legacyItemId;
    @Column(nullable=false) private String ingredientName;
    @Column(nullable=false,length=40) private String state;
    @Column(precision=80,scale=0) private BigInteger numerator;
    @Column(precision=80,scale=0) private BigInteger denominator;
    private String unit;
    protected GroceryContributionLine() {}
    public GroceryContributionLine(Long ingredientId,String name,String state,QuantityScaling.Quantity quantity,String unit) {
        this.ingredientId=ingredientId;this.ingredientName=name;this.state=state;this.unit=unit;
        if(quantity!=null){this.numerator=quantity.numerator();this.denominator=quantity.denominator();}
    }
    public Long getIngredientId(){return ingredientId;}
    public Long getLegacyItemId(){return legacyItemId;}
    public String getIngredientName(){return ingredientName;}
    public String getState(){return state;}
    public String getUnit(){return unit;}
    public QuantityScaling.Quantity quantity(){return numerator==null ? null : new QuantityScaling.Quantity(numerator,denominator);}
}
