package de.frauas.girokonto.common;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class IbanTest {

    @Test
    void erzeugtGueltigeDeutscheIban() {
        String iban = Iban.forAccountNumber(1000000001L);

        assertEquals(22, iban.length());
        assertTrue(iban.startsWith("DE"));
        assertEquals("990000001000000001", iban.substring(4));
        assertTrue(Iban.isValid(iban));
    }

    @Test
    void erkenntBekannteGueltigeIban() {
        assertTrue(Iban.isValid("DE89 3704 0044 0532 0130 00"));
    }

    @Test
    void erkenntTippfehler() {
        assertFalse(Iban.isValid("DE89 3704 0044 0532 0130 01"));
        assertFalse(Iban.isValid("hallo"));
        assertFalse(Iban.isValid(null));
    }
}
