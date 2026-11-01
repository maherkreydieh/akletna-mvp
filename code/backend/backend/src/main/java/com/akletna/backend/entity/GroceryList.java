package com.akletna.backend.entity;

import jakarta.persistence.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "grocery_lists")
public class GroceryList {
    @Column(nullable=false,columnDefinition="boolean default false")
    private boolean contributionsInitialized = true;

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @OneToMany(mappedBy = "groceryList", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<GroceryItem> items = new ArrayList<>();

    public GroceryList() {
    }

    public GroceryList(User user, LocalDateTime updatedAt) {
        this.user = user;
        this.updatedAt = updatedAt;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public User getUser() {
        return user;
    }

    public void setUser(User user) {
        this.user = user;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    public List<GroceryItem> getItems() {
        return items;
    }

    public void setItems(List<GroceryItem> items) {
        this.items = items;
    }

    public void addItem(GroceryItem item) {
        items.add(item);
        item.setGroceryList(this);
    }
}
