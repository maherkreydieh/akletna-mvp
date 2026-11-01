package com.akletna.backend.entity;
public enum MealGoal {
    BUDGET_FRIENDLY("Budget Friendly"), HIGH_PROTEIN("High Protein");
    private final String label;
    MealGoal(String label) { this.label=label; }
    public String label() { return label; }
}
