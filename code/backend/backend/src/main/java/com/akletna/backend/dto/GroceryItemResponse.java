package com.akletna.backend.dto;

public class GroceryItemResponse {

    private Long id;
    private String name;
    private Double quantity;
    private String unit;
    private boolean checked;

    public GroceryItemResponse() {
    }

    public GroceryItemResponse(Long id, String name, Double quantity, String unit, boolean checked) {
        this.id = id;
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

    // Additive presentation fields; quantity/unit remain the stored canonical pair.
    public java.math.BigDecimal getDisplayQuantity() {
        return display().quantity();
    }
    public String getDisplayUnit() { return display().unit(); }
    private com.akletna.backend.service.QuantityUnit.Display display() {
        return com.akletna.backend.service.QuantityUnit.of(unit).display(java.math.BigDecimal.valueOf(quantity));
    }

    public void setChecked(boolean checked) {
        this.checked = checked;
    }
}
