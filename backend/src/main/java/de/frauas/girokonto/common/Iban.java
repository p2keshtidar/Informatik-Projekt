package de.frauas.girokonto.common;

import java.math.BigInteger;

// Deutsche IBAN nach ISO 13616: DE + 2 Prüfziffern + 8 Stellen BLZ + 10 Stellen Kontonummer
public final class Iban {

    // fiktive Bankleitzahl der Projektbank
    public static final String BANK_CODE = "99000000";

    private static final BigInteger NINETY_SEVEN = BigInteger.valueOf(97);

    private Iban() {
    }

    public static String forAccountNumber(long accountNumber) {
        String bban = BANK_CODE + String.format("%010d", accountNumber);
        // "DE00" ans Ende, D = 13, E = 14
        int check = 98 - new BigInteger(bban + "131400").mod(NINETY_SEVEN).intValue();
        return "DE" + String.format("%02d", check) + bban;
    }

    public static boolean isValid(String iban) {
        if (iban == null) {
            return false;
        }
        String s = iban.replace(" ", "").toUpperCase();
        if (!s.matches("[A-Z]{2}[0-9]{2}[A-Z0-9]{10,30}")) {
            return false;
        }
        String rearranged = s.substring(4) + s.substring(0, 4);
        StringBuilder digits = new StringBuilder();
        for (char c : rearranged.toCharArray()) {
            digits.append(Character.isDigit(c) ? String.valueOf(c) : String.valueOf(c - 'A' + 10));
        }
        return new BigInteger(digits.toString()).mod(NINETY_SEVEN).intValue() == 1;
    }
}
