package com.akletna.backend.entity;
public enum DietaryPreference {
    VEGETARIAN("Vegetarian"), VEGAN("Vegan");
    private final String label;
    DietaryPreference(String label) { this.label=label; }
    public String label() { return label; }
}
