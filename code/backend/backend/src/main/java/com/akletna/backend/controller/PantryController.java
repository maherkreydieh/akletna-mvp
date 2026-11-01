package com.akletna.backend.controller;

import com.akletna.backend.dto.*;
import com.akletna.backend.service.PantryService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController @RequestMapping("/api/pantry")
public class PantryController {
    private final PantryService pantry;
    public PantryController(PantryService pantry) { this.pantry=pantry; }
    @GetMapping public List<PantryItemResponse> list(Authentication auth) { return pantry.list(auth.getName()); }
    @GetMapping("/{id}") public PantryItemResponse get(@PathVariable Long id,Authentication auth) { return pantry.get(id,auth.getName()); }
    @PostMapping public ResponseEntity<PantryItemResponse> add(@Valid @RequestBody PantryItemRequest request,Authentication auth) {
        return ResponseEntity.status(201).body(pantry.add(request,auth.getName()));
    }
    @PutMapping("/{id}") public PantryItemResponse update(@PathVariable Long id,@Valid @RequestBody PantryQuantityRequest request,Authentication auth) {
        return pantry.update(id,request,auth.getName());
    }
    @DeleteMapping("/{id}") public ResponseEntity<Void> remove(@PathVariable Long id,Authentication auth) {
        pantry.remove(id,auth.getName()); return ResponseEntity.noContent().build();
    }
}
