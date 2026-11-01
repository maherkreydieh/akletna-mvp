package com.akletna.backend.entity;

import jakarta.persistence.*;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import java.time.Instant;

@Entity
@Table(name = "saved_recipes", uniqueConstraints = @UniqueConstraint(name = "uk_saved_user_recipe", columnNames = {"user_id", "recipe_id"}),
        indexes = @Index(name = "ix_saved_recipe", columnList = "recipe_id"))
public class SavedRecipe {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    @ManyToOne(optional = false) @JoinColumn(name = "user_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private User user;
    @ManyToOne(optional = false) @JoinColumn(name = "recipe_id", nullable = false)
    @OnDelete(action = OnDeleteAction.CASCADE)
    private Recipe recipe;
    @Column(nullable = false, updatable = false)
    private Instant savedAt;
    protected SavedRecipe() {}
    public SavedRecipe(User user, Recipe recipe) {
        this.user = user; this.recipe = recipe; this.savedAt = Instant.now();
    }
    public Long getId() { return id; }
    public Recipe getRecipe() { return recipe; }
    public Instant getSavedAt() { return savedAt; }
}
