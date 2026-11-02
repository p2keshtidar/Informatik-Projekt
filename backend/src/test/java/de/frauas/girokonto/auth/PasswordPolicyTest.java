package de.frauas.girokonto.auth;

import de.frauas.girokonto.auth.PasswordPolicy.Rule;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class PasswordPolicyTest {

    private static java.util.List<Rule> check(String pw) {
        return PasswordPolicy.violations(pw, "anna.muster@test.de", "Anna", "Muster");
    }

    @Test
    void sicheresPasswortIstOk() {
        assertTrue(check("Kontor!Blau7Wald").isEmpty());
    }

    @Test
    void zuKurzUndOhneZeichenarten() {
        assertEquals(java.util.List.of(Rule.LENGTH, Rule.UPPER, Rule.DIGIT, Rule.SPECIAL), check("kurz"));
    }

    @Test
    void nameOderEmailImPasswort() {
        assertTrue(check("Muster!Konto77x").contains(Rule.PERSONAL));
        assertTrue(check("Xanna#Konto77y").contains(Rule.PERSONAL));
    }

    @Test
    void folgenUndWiederholungen() {
        assertTrue(check("Konto!1234Blau").contains(Rule.SEQUENCE));
        assertTrue(check("Konto!aaaaBlau7").contains(Rule.SEQUENCE));
        assertTrue(check("Konto!dcbaBlau7").contains(Rule.SEQUENCE));
        assertFalse(check("Konto!1357Blau").contains(Rule.SEQUENCE));
    }

    @Test
    void bekanntePasswoerter() {
        assertTrue(check("Passwort2024!").contains(Rule.COMMON));
        assertTrue(check("Willkommen99!").contains(Rule.COMMON));
    }
}
