package de.frauas.girokonto.auth;

import de.frauas.girokonto.common.ApiException;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;

// Regeln für ein sicheres Passwort. Die App prüft dieselben Regeln (app/lib/util/password_rules.dart).
public final class PasswordPolicy {

    public static final int MIN_LENGTH = 12;

    public static final String MESSAGE = "Das Passwort ist nicht sicher genug: mindestens 12 Zeichen mit Groß- und "
            + "Kleinbuchstaben, Ziffer und Sonderzeichen, ohne Name oder E-Mail, ohne Folgen wie „1234“ "
            + "und kein bekanntes Passwort.";

    private static final Set<String> COMMON = Set.of(
            "passwort", "password", "qwertz", "qwerty", "qwertzuiop", "qwertyuiop", "hallo", "letmein",
            "willkommen", "welcome", "geheim", "admin", "iloveyou", "sommer", "winter", "fussball",
            "football", "schatz", "dragon", "monkey");

    public enum Rule { LENGTH, LOWER, UPPER, DIGIT, SPECIAL, PERSONAL, SEQUENCE, COMMON }

    private PasswordPolicy() {
    }

    public static void check(String password, String email, String firstName, String lastName) {
        if (!violations(password, email, firstName, lastName).isEmpty()) {
            throw ApiException.badRequest(MESSAGE);
        }
    }

    public static List<Rule> violations(String password, String email, String firstName, String lastName) {
        String pw = password == null ? "" : password;
        String lower = pw.toLowerCase(Locale.ROOT);
        List<Rule> result = new ArrayList<>();

        if (pw.length() < MIN_LENGTH) result.add(Rule.LENGTH);
        if (pw.chars().noneMatch(Character::isLowerCase)) result.add(Rule.LOWER);
        if (pw.chars().noneMatch(Character::isUpperCase)) result.add(Rule.UPPER);
        if (pw.chars().noneMatch(Character::isDigit)) result.add(Rule.DIGIT);
        if (pw.chars().allMatch(Character::isLetterOrDigit)) result.add(Rule.SPECIAL);
        if (personalParts(email, firstName, lastName).stream().anyMatch(lower::contains)) result.add(Rule.PERSONAL);
        if (hasRunOrSequence(lower)) result.add(Rule.SEQUENCE);
        if (isCommon(lower)) result.add(Rule.COMMON);
        return result;
    }

    // z. B. "anna", "muster" aus anna.muster@test.de; nur Teile ab 3 Zeichen mit Buchstaben
    static List<String> personalParts(String email, String firstName, String lastName) {
        List<String> parts = new ArrayList<>();
        if (email != null && email.contains("@")) {
            addParts(parts, email.substring(0, email.indexOf('@')), "[^\\p{L}0-9]+");
        }
        addParts(parts, firstName, "[\\s-]+");
        addParts(parts, lastName, "[\\s-]+");
        return parts;
    }

    private static void addParts(List<String> parts, String text, String separator) {
        if (text == null) {
            return;
        }
        for (String s : text.toLowerCase(Locale.ROOT).split(separator)) {
            if (s.length() >= 3 && s.chars().anyMatch(Character::isLetter)) {
                parts.add(s);
            }
        }
    }

    // vier gleiche Zeichen ("aaaa") oder vier aufeinanderfolgende ("1234", "abcd", "4321")
    static boolean hasRunOrSequence(String s) {
        for (int i = 0; i + 3 < s.length(); i++) {
            int d1 = s.charAt(i + 1) - s.charAt(i);
            int d2 = s.charAt(i + 2) - s.charAt(i + 1);
            int d3 = s.charAt(i + 3) - s.charAt(i + 2);
            boolean same = d1 == 0 && d2 == 0 && d3 == 0;
            boolean step = Character.isLetterOrDigit(s.charAt(i)) && d1 == d2 && d2 == d3 && Math.abs(d1) == 1;
            if (same || step) {
                return true;
            }
        }
        return false;
    }

    // "Passwort123!" zählt auch als bekannt: Sonderzeichen und Zahlen am Ende werden ignoriert
    static boolean isCommon(String lower) {
        String letters = lower.replaceAll("[^\\p{L}0-9]", "");
        return COMMON.contains(letters) || COMMON.contains(letters.replaceAll("[0-9]+$", ""));
    }
}
