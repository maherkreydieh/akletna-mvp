package com.akletna.backend.dto;

import jakarta.validation.constraints.*;
import java.math.BigDecimal;

public class PantryQuantityRequest {
    @Positive(message="Quantity must be positive. Remove the ingredient when you no longer have it.")
    @Digits(integer=15,fraction=12,message="Quantity supports up to 15 integer and 12 fractional digits.")
    private BigDecimal quantity;
    @Size(max=30,message="Unit cannot exceed 30 characters.")
    private String unit;
    public BigDecimal getQuantity() { return quantity; }
    public void setQuantity(BigDecimal value) { quantity=value; }
    public String getUnit() { return unit; }
    public void setUnit(String value) { unit=value; }
}
