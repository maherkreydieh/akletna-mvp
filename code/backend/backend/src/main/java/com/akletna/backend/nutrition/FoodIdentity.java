package com.akletna.backend.nutrition;

/** An explicit trusted mapping, including preparation state; never a name lookup. */
public record FoodIdentity(String provider, String externalFoodId, String preparationState) { }
