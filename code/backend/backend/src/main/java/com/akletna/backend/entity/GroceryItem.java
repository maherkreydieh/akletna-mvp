package com.akletna.backend.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "grocery_items")
public class GroceryItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "grocery_list_id", nullable = false)
    private GroceryList groceryList;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false)
    private Double quantity;

    private String unit;

    @Column(nullable = false)
    private boolean checked = false;

    public GroceryItem() {
    }

    public GroceryItem(GroceryList groceryList, String name, Double quantity, String unit, boolean checked) {
        this.groceryList = groceryList;
        this.name = name;
        this.quantity = quantity;
        this.unit = unit;
        this.checked = checked;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public GroceryList getGroceryList() {
        return groceryList;
    }

    public void setGroceryList(GroceryList groceryList) {
        this.groceryList = groceryList;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public Double getQuantity() {
        return quantity;
    }

    public void setQuantity(Double quantity) {
        this.quantity = quantity;
    }

    public String getUnit() {
        return unit;
    }

    public void setUnit(String unit) {
        this.unit = unit;
    }

    public boolean isChecked() {
        return checked;
    }

    public void setChecked(boolean checked) {
        this.checked = checked;
    }
}