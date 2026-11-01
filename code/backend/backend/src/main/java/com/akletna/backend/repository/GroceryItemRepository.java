package com.akletna.backend.repository;

import com.akletna.backend.entity.GroceryItem;
import com.akletna.backend.entity.GroceryList;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface GroceryItemRepository extends JpaRepository<GroceryItem, Long> {
    Optional<GroceryItem> findByIdAndGroceryList(Long id, GroceryList groceryList);
}