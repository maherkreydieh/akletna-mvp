package com.akletna.backend.exception;

import com.akletna.backend.dto.ErrorResponse;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.stream.Collectors;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(org.springframework.web.bind.MissingServletRequestParameterException.class)
    public ResponseEntity<ErrorResponse> handleMissingParameter(HttpServletRequest request) {
        return ResponseEntity.badRequest().body(new ErrorResponse(400, "Bad Request", "A required parameter is missing.", request.getRequestURI()));
    }

    @ExceptionHandler(org.springframework.web.HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ErrorResponse> handleMethod(HttpServletRequest request) {
        return ResponseEntity.status(405).body(new ErrorResponse(405, "Method Not Allowed", "This request method is not supported.", request.getRequestURI()));
    }

    @ExceptionHandler(org.springframework.web.HttpMediaTypeNotSupportedException.class)
    public ResponseEntity<ErrorResponse> handleMediaType(HttpServletRequest request) {
        return ResponseEntity.status(415).body(new ErrorResponse(415, "Unsupported Media Type", "Use a supported request content type.", request.getRequestURI()));
    }

    @ExceptionHandler({org.springframework.dao.DataIntegrityViolationException.class,
            org.springframework.dao.ConcurrencyFailureException.class})
    public ResponseEntity<ErrorResponse> handleDatabaseConflict(HttpServletRequest request) {
        return ResponseEntity.status(409).body(new ErrorResponse(409, "Conflict", "The data changed or conflicts with an existing record. Refresh and try again.", request.getRequestURI()));
    }
    @ExceptionHandler(org.springframework.web.method.annotation.MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ErrorResponse> handleFilterValue(HttpServletRequest request) {
        return ResponseEntity.badRequest().body(new ErrorResponse(400,"Bad Request","Choose a supported filter value.",request.getRequestURI()));
    }

    @ExceptionHandler(ConflictException.class)
    public ResponseEntity<ErrorResponse> handleConflict(ConflictException ex,HttpServletRequest request) {
        return ResponseEntity.status(409).body(new ErrorResponse(409,"Conflict",ex.getMessage(),request.getRequestURI()));
    }

    @ExceptionHandler(com.akletna.backend.nutrition.ProviderUnavailableException.class)
    public ResponseEntity<ErrorResponse> handleNutritionProvider(HttpServletRequest request) {
        return ResponseEntity.status(503).body(new ErrorResponse(503, "Service Unavailable",
                "Nutrition provider is unavailable. Try again later.", request.getRequestURI()));
    }

    @ExceptionHandler(org.springframework.http.converter.HttpMessageNotReadableException.class)
    public ResponseEntity<ErrorResponse> handleUnreadableRequest(HttpServletRequest request) {
        return ResponseEntity.badRequest().body(new ErrorResponse(400, "Bad Request",
                "Invalid request body. Check the submitted values.", request.getRequestURI()));
    }

    @ExceptionHandler(ResourceNotFoundException.class)
    public ResponseEntity<ErrorResponse> handleResourceNotFound(ResourceNotFoundException ex, HttpServletRequest request) {
        ErrorResponse error = new ErrorResponse(
                HttpStatus.NOT_FOUND.value(),
                HttpStatus.NOT_FOUND.getReasonPhrase(),
                ex.getMessage(),
                request.getRequestURI()
        );
        return new ResponseEntity<>(error, HttpStatus.NOT_FOUND);
    }

    @ExceptionHandler(UnauthorizedResourceException.class)
    public ResponseEntity<ErrorResponse> handleUnauthorizedResource(UnauthorizedResourceException ex, HttpServletRequest request) {
        ErrorResponse error = new ErrorResponse(
                HttpStatus.FORBIDDEN.value(),
                HttpStatus.FORBIDDEN.getReasonPhrase(),
                ex.getMessage(),
                request.getRequestURI()
        );
        return new ResponseEntity<>(error, HttpStatus.FORBIDDEN);
    }

    @ExceptionHandler(BadRequestException.class)
    public ResponseEntity<ErrorResponse> handleBadRequest(BadRequestException ex, HttpServletRequest request) {
        ErrorResponse error = new ErrorResponse(
                HttpStatus.BAD_REQUEST.value(),
                HttpStatus.BAD_REQUEST.getReasonPhrase(),
                ex.getMessage(),
                request.getRequestURI()
        );
        return new ResponseEntity<>(error, HttpStatus.BAD_REQUEST);
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<ErrorResponse> handleValidationErrors(MethodArgumentNotValidException ex, HttpServletRequest request) {
        String combinedErrors = ex.getBindingResult()
                .getFieldErrors()
                .stream()
                .map(FieldError::getDefaultMessage)
                .collect(Collectors.joining("; "));

        ErrorResponse error = new ErrorResponse(
                HttpStatus.BAD_REQUEST.value(),
                "Validation Failed",
                combinedErrors,
                request.getRequestURI()
        );
        return new ResponseEntity<>(error, HttpStatus.BAD_REQUEST);
    }

    @ExceptionHandler(Exception.class)
    public ResponseEntity<ErrorResponse> handleGeneralException(Exception ex, HttpServletRequest request) {
        ErrorResponse error = new ErrorResponse(
                HttpStatus.INTERNAL_SERVER_ERROR.value(),
                HttpStatus.INTERNAL_SERVER_ERROR.getReasonPhrase(),
                "An unexpected server error occurred.",
                request.getRequestURI()
        );
        return new ResponseEntity<>(error, HttpStatus.INTERNAL_SERVER_ERROR);
    }
}
