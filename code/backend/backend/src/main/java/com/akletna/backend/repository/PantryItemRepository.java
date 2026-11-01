package com.akletna.backend.repository;

import com.akletna.backend.entity.PantryItem;
import org.springframework.data.jpa.repository.*;
import java.util.List;
import java.util.Optional;

public interface PantryItemRepository extends JpaRepository<PantryItem,Long> {
    boolean existsByUserIdAndIngredientId(Long userId,Long ingredientId);
    @Query("select p from PantryItem p join fetch p.ingredient i where p.user.id=:userId order by lower(i.name), i.id, p.id")
    List<PantryItem> findForUser(Long userId);
    @Query("select p from PantryItem p join fetch p.ingredient where p.id=:id and p.user.id=:userId")
    Optional<PantryItem> findForUserById(Long userId,Long id);
}
