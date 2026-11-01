package com.akletna.backend.exception;

public class UnauthorizedResourceException extends RuntimeException {
    public UnauthorizedResourceException(String message) {
        super(message);
    }
}