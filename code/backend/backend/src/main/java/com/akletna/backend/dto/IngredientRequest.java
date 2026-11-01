package com.akletna.backend.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public class IngredientRequest {

    @NotBlank(message = "Ingredient name is required")
    @Size(min = 2, max = 100, message = "Ingredient name must be between 2 and 100 characters")
    private String name;

    @NotBlank(message = "Measurement unit is required (e.g., g, ml, cup, tbsp, piece)")
    @Size(max = 30, message = "Unit cannot exceed 30 characters")
    private String unit;

    public IngredientRequest() {
    }

    public IngredientRequest(String name, String unit) {
        this.name = name;
        this.unit = unit;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getUnit() {
        return unit;
    }

    public void setUnit(String unit) {
        this.unit = unit;
    }
}