package com.akletna.backend.dto;

import java.time.LocalDateTime;
import java.util.List;

public class GroceryListResponse {
    private List<GroceryContributionResponse> contributions = List.of();
    public List<GroceryContributionResponse> getContributions(){return contributions;}
    public void setContributions(List<GroceryContributionResponse> values){contributions=values;}

    private Long id;
    private LocalDateTime updatedAt;
    private List<GroceryItemResponse> items;

    public GroceryListResponse() {
    }

    public GroceryListResponse(Long id, LocalDateTime updatedAt, List<GroceryItemResponse> items) {
        this.id = id;
        this.updatedAt = updatedAt;
        this.items = items;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    public List<GroceryItemResponse> getItems() {
        return items;
    }

    public void setItems(List<GroceryItemResponse> items) {
        this.items = items;
    }
}
