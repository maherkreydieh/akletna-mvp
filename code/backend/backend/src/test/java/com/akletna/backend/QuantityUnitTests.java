package com.akletna.backend;

import com.akletna.backend.service.*;
import java.math.BigDecimal;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class QuantityUnitTests {
    private static BigDecimal d(String value) { return new BigDecimal(value); }
    @Test void decimalConversionsAreExactAndAliasesConservative() {
        for (var row : new String[][] {{"g","1","1"},{"KG","0.1","100"},{"kg","0.333","333"},{"ml","500","500"},{" L ","0.75","750"}})
            assertEquals(0,d(row[2]).compareTo(QuantityUnit.of(row[0]).canonicalQuantity(d(row[1]))));
        assertEquals("mL",QuantityUnit.normalizeInput(" ML ")); assertEquals("kg",QuantityUnit.normalizeInput("Kg"));
        assertEquals("L",QuantityUnit.normalizeInput("l")); assertEquals("cup",QuantityUnit.normalizeInput("CUP"));
        assertEquals("clove",QuantityUnit.normalizeInput(" clove "));
        for (String unit : new String[]{"gram","grams","kilogram","milliliter","litre","cups","pieces"})
            assertEquals(QuantityUnit.Dimension.OTHER,QuantityUnit.of(unit).dimension());
    }
    @Test void compatibilityOnlyMatchesDimensionAndCanonicalUnit() {
        for (var pair : new String[][]{{"g","kg"},{"mL","L"},{"cup","CUP"},{"piece","piece"},{"clove","CLOVE"}})
            assertTrue(QuantityUnit.of(pair[0]).compatibleWith(QuantityUnit.of(pair[1])));
        for (var pair : new String[][]{{"g","mL"},{"g","cup"},{"kg","piece"},{"cup","mL"},{"tbsp","tsp"},{"piece","pieces"}})
            assertFalse(QuantityUnit.of(pair[0]).compatibleWith(QuantityUnit.of(pair[1])));
    }
    @Test void finalCanonicalRoundingPrecedesExactDisplayThresholdSelection() {
        for (String unit : new String[]{"g","mL"}) {
            String larger = unit.equals("g") ? "kg" : "L";
            assertEquals(unit,QuantityUnit.of(unit).display(d("999.99")).unit());
            assertEquals(larger,QuantityUnit.of(unit).display(d("1000")).unit());
            assertEquals(0,d("1.50001").compareTo(QuantityUnit.of(unit).display(d("1500.01")).quantity()));
            var rounded = QuantityScaling.effectiveQuantity(d("999.995"),1,1).rounded(2);
            assertEquals(larger,QuantityUnit.of(unit).display(rounded).unit());
        }
        assertEquals("piece",QuantityUnit.of("piece").display(d("1500")).unit());
    }
}
