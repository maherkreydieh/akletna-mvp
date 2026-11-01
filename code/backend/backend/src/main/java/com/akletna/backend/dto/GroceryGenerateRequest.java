package com.akletna.backend.dto;

import java.time.LocalDate;

public class GroceryGenerateRequest {

    private LocalDate startDate;
    private LocalDate endDate;

    public GroceryGenerateRequest() {
    }

    public GroceryGenerateRequest(LocalDate startDate, LocalDate endDate) {
        this.startDate = startDate;
        this.endDate = endDate;
    }

    public LocalDate getStartDate() {
        return startDate;
    }

    public void setStartDate(LocalDate startDate) {
        this.startDate = startDate;
    }

    public LocalDate getEndDate() {
        return endDate;
    }

    public void setEndDate(LocalDate endDate) {
        this.endDate = endDate;
    }
}
