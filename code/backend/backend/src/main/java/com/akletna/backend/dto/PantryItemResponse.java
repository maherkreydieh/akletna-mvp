package com.akletna.backend.dto;
import java.time.Instant;

// Plain decimal strings preserve all inventory digits in mobile JSON clients.
public record PantryItemResponse(Long id,Long ingredientId,String ingredientName,String quantity,
                                 String unit,String displayQuantity,String displayUnit,Instant updatedAt) {}
