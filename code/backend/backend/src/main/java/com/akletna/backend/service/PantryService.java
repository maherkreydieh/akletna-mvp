package com.akletna.backend.service;

import com.akletna.backend.dto.*;
import com.akletna.backend.entity.PantryItem;
import com.akletna.backend.exception.*;
import com.akletna.backend.repository.PantryItemRepository;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
import java.util.List;

@Service
public class PantryService {
    private static final String DUPLICATE="This ingredient is already in your pantry. Edit the existing item.";
    private final PantryItemRepository items;
    private final UserService users;
    private final IngredientService ingredients;
    public PantryService(PantryItemRepository items,UserService users,IngredientService ingredients) {
        this.items=items; this.users=users; this.ingredients=ingredients;
    }
    @Transactional(readOnly=true)
    public List<PantryItemResponse> list(String email) {
        return items.findForUser(users.getUserByEmail(email).getId()).stream().map(this::response).toList();
    }
    @Transactional(readOnly=true)
    public PantryItemResponse get(Long id,String email) { return response(owned(id,email)); }
    @Transactional
    public PantryItemResponse add(PantryItemRequest request,String email) {
        var user=users.getUserByEmail(email);
        var ingredient=ingredients.getIngredientEntity(request.getIngredientId());
        if (items.existsByUserIdAndIngredientId(user.getId(),ingredient.getId())) throw new ConflictException(DUPLICATE);
        var item=new PantryItem(); item.setUser(user); item.setIngredient(ingredient);
        apply(item,request);
        try { return response(items.saveAndFlush(item)); }
        catch (DataIntegrityViolationException ex) {
            // The unique key is the final protection against simultaneous adds.
            for (Throwable cause=ex;cause!=null;cause=cause.getCause())
                if (cause instanceof org.hibernate.exception.ConstraintViolationException violation &&
                        "uk_pantry_user_ingredient".equals(violation.getConstraintName())) throw new ConflictException(DUPLICATE);
            throw ex;
        }
    }
    @Transactional
    public PantryItemResponse update(Long id,PantryQuantityRequest request,String email) {
        var item=owned(id,email); apply(item,request); return response(items.saveAndFlush(item));
    }
    @Transactional
    public void remove(Long id,String email) { items.delete(owned(id,email)); }
    private PantryItem owned(Long id,String email) {
        return items.findForUserById(users.getUserByEmail(email).getId(),id)
                .orElseThrow(()->new ResourceNotFoundException("Pantry item not found."));
    }
    private void apply(PantryItem item,PantryQuantityRequest request) {
        var quantity=request.getQuantity(); var unit=request.getUnit();
        if ((quantity==null)!=(unit==null) || (unit!=null && unit.isBlank()))
            throw new BadRequestException("Provide both quantity and unit, or leave both empty for an ingredient you have without a known amount.");
        if (quantity!=null && (quantity.signum()<=0 || quantity.scale()>12 || quantity.precision()-quantity.scale()>15))
            throw new BadRequestException("Quantity must be positive and support at most 15 integer and 12 fractional digits.");
        if (unit!=null && unit.length()>30) throw new BadRequestException("Unit cannot exceed 30 characters.");
        if (quantity==null) { item.setQuantity(null); item.setUnit(null); }
        else {
            var measurement=QuantityUnit.of(unit);
            var canonical=measurement.canonicalQuantity(quantity);
            if (canonical.precision()-canonical.scale()>15) throw new BadRequestException("The normalized amount is too large to store. Use a smaller quantity.");
            item.setQuantity(canonical);
            item.setUnit(measurement.dimension()==QuantityUnit.Dimension.OTHER ? measurement.symbol() : measurement.canonicalUnit());
        }
        item.setUpdatedAt(Instant.now());
    }
    private PantryItemResponse response(PantryItem item) {
        var display=item.getQuantity()==null ? null : QuantityUnit.of(item.getUnit()).display(item.getQuantity());
        return new PantryItemResponse(item.getId(),item.getIngredient().getId(),item.getIngredient().getName(),
                decimal(item.getQuantity()),item.getUnit(),display==null?null:decimal(display.quantity()),display==null?null:display.unit(),item.getUpdatedAt());
    }
    private static String decimal(java.math.BigDecimal value) { return value==null?null:value.stripTrailingZeros().toPlainString(); }
}
