package com.akletna.backend.service;

import com.akletna.backend.exception.BadRequestException;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.math.RoundingMode;

/** Exact contextual quantities: no binary arithmetic or intermediate division rounding. */
public final class QuantityScaling {
    private QuantityScaling() {}
    public static void validateServings(Integer baseServings, Integer plannedServings) {
        if (baseServings == null || baseServings <= 0)
            throw new BadRequestException("This recipe has no valid base serving count. Correct the recipe before planning or generating groceries.");
        if (plannedServings == null || plannedServings <= 0)
            throw new BadRequestException("Planned servings must be a positive whole number. Update the meal plan before generating groceries.");
    }
    public static Quantity effectiveQuantity(BigDecimal quantity, Integer plannedServings, Integer baseServings) {
        validateServings(baseServings, plannedServings);
        if (quantity == null || quantity.signum() <= 0)
            throw new BadRequestException("A planned recipe has an invalid ingredient quantity. Correct the recipe before generating groceries.");
        BigDecimal numerator = quantity.multiply(BigDecimal.valueOf(plannedServings));
        BigInteger top = numerator.unscaledValue();
        BigInteger bottom = BigInteger.valueOf(baseServings);
        if (numerator.scale() >= 0) bottom = bottom.multiply(BigInteger.TEN.pow(numerator.scale()));
        else top = top.multiply(BigInteger.TEN.pow(-numerator.scale()));
        return new Quantity(top, bottom);
    }
    // A finite decimal divided by integer servings can recur. Keep the exact fraction
    // until the storage boundary, including HALF_UP ties after multiple contributions.
    public record Quantity(BigInteger numerator, BigInteger denominator) {
        public static Quantity of(BigDecimal value) {
            return value.scale() >= 0
                    ? new Quantity(value.unscaledValue(), BigInteger.TEN.pow(value.scale()))
                    : new Quantity(value.unscaledValue().multiply(BigInteger.TEN.pow(-value.scale())), BigInteger.ONE);
        }
        public Quantity subtract(Quantity other) {
            return add(new Quantity(other.numerator.negate(), other.denominator));
        }
        public int compareTo(Quantity other) {
            return numerator.multiply(other.denominator).compareTo(other.numerator.multiply(denominator));
        }
        public Quantity divide(Quantity other) {
            return new Quantity(numerator.multiply(other.denominator), denominator.multiply(other.numerator));
        }
        public Quantity {
            if (denominator.signum() <= 0) throw new IllegalArgumentException("Positive denominator required.");
            BigInteger divisor = numerator.gcd(denominator);
            numerator = numerator.divide(divisor); denominator = denominator.divide(divisor);
        }
        public Quantity add(Quantity other) {
            return new Quantity(numerator.multiply(other.denominator).add(other.numerator.multiply(denominator)),
                    denominator.multiply(other.denominator));
        }
        public Quantity multiply(int factor) {
            return new Quantity(numerator.multiply(BigInteger.valueOf(factor)), denominator);
        }
        public BigDecimal rounded(int scale) {
            return new BigDecimal(numerator).divide(new BigDecimal(denominator), scale, RoundingMode.HALF_UP);
        }
    }
}
