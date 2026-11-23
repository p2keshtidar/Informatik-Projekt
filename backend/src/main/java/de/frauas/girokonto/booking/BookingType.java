package de.frauas.girokonto.booking;

// Muss zu ck_booking_type in der Datenbank passen (V1 + V2)
public enum BookingType {
    TRANSFER,
    INTERNAL,
    CARD,
    SAVINGS_RATE,
    SAVINGS_PAYOUT,
    LOAN_PAYOUT,
    LOAN_RATE,
    OPENING
}
