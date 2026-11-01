package com.akletna.backend.service;

import com.akletna.backend.dto.LoginRequest;
import com.akletna.backend.dto.RegisterRequest;
import com.akletna.backend.dto.UserResponse;
import com.akletna.backend.entity.User;
import com.akletna.backend.exception.BadRequestException;
import com.akletna.backend.exception.ResourceNotFoundException;
import com.akletna.backend.repository.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public UserService(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    public UserResponse registerUser(RegisterRequest request) {
        validatePasswordLength(request.getPassword());
        if (userRepository.existsByEmail(normalizeEmail(request.getEmail()))) {
            throw new BadRequestException("Email is already registered!");
        }

        String hashedPassword = passwordEncoder.encode(request.getPassword());

        User newUser = new User();
        newUser.setName(request.getName().trim());
        newUser.setEmail(normalizeEmail(request.getEmail()));
        newUser.setPassword(hashedPassword);

        User savedUser;
        try {
            savedUser = userRepository.saveAndFlush(newUser);
        } catch (org.springframework.dao.DataIntegrityViolationException ex) {
            // A competing registration may have won after the existence check.
            if (userRepository.existsByEmail(newUser.getEmail())) {
                throw new BadRequestException("Email is already registered!");
            }
            throw ex;
        }
        return new UserResponse(savedUser.getId(), savedUser.getName(), savedUser.getEmail());
    }

    public User authenticateUser(LoginRequest loginRequest) {
        validatePasswordLength(loginRequest.getPassword());
        User user = userRepository.findByEmail(normalizeEmail(loginRequest.getEmail()))
                .orElseThrow(() -> new BadRequestException("Invalid email or password!"));

        if (!passwordEncoder.matches(loginRequest.getPassword(), user.getPassword())) {
            throw new BadRequestException("Invalid email or password!");
        }

        return user;
    }

    public User getUserByEmail(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new ResourceNotFoundException("User not found."));
    }

    public UserResponse getUserProfile(String email) {
        User user = getUserByEmail(email);
        return new UserResponse(user.getId(), user.getName(), user.getEmail());
    }

    private static String normalizeEmail(String email) {
        return email.trim().toLowerCase(java.util.Locale.ROOT);
    }

    private static void validatePasswordLength(String password) {
        if (password == null || password.getBytes(java.nio.charset.StandardCharsets.UTF_8).length > 72) {
            throw new BadRequestException("Password must not exceed 72 UTF-8 bytes.");
        }
    }
}
