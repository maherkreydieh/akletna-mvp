package com.akletna.backend.dto;

import jakarta.validation.constraints.*;

public class RecipeShortageRequest {
    @NotNull @Positive private Integer servings;
    public Integer getServings(){return servings;}
    @com.fasterxml.jackson.annotation.JsonSetter("servings")
    public void readServings(tools.jackson.databind.JsonNode value) {
        if(value==null || value.isNull()){servings=null;return;}
        if(!value.isIntegralNumber() || !value.canConvertToInt()) throw new IllegalArgumentException("Servings must be a positive whole number.");
        servings=value.intValue();
    }
}
