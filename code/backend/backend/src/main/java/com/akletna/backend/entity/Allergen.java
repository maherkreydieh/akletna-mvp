package com.akletna.backend.entity;
public enum Allergen {
    DAIRY("dairy"), EGG("egg"), PEANUT("peanut"), TREE_NUT("tree nuts"),
    SESAME("sesame"), SOY("soy"), WHEAT("wheat"), GLUTEN("gluten"),
    FISH("fish"), SHELLFISH("shellfish");
    private final String label;
    Allergen(String label) { this.label=label; }
    public String label() { return label; }
}
