package com.akletna.backend.repository;

import com.akletna.backend.entity.GroceryList;
import com.akletna.backend.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface GroceryListRepository extends JpaRepository<GroceryList, Long> {
    Optional<GroceryList> findByUser(User user);
}