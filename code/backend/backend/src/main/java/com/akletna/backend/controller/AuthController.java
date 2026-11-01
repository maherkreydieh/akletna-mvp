package com.akletna.backend.controller;

import com.akletna.backend.dto.AuthResponse;
import com.akletna.backend.dto.LoginRequest;
import com.akletna.backend.dto.RegisterRequest;
import com.akletna.backend.dto.UserResponse;
import com.akletna.backend.entity.User;
import com.akletna.backend.service.JwtService;
import com.akletna.backend.service.UserService;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final UserService userService;
    private final JwtService jwtService;

    public AuthController(UserService userService, JwtService jwtService) {
        this.userService = userService;
        this.jwtService = jwtService;
    }

    @PostMapping("/register")
    public ResponseEntity<UserResponse> registerUser(@Valid @RequestBody RegisterRequest request) {
        UserResponse response = userService.registerUser(request);
        return new ResponseEntity<>(response, HttpStatus.CREATED);
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> loginUser(@Valid @RequestBody LoginRequest request) {
        User user = userService.authenticateUser(request);
        String token = jwtService.generateToken(user);
        AuthResponse response = new AuthResponse(token, user.getEmail(), user.getName());
        return ResponseEntity.ok(response);
    }
}