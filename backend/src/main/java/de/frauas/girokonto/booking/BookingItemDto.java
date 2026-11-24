package de.frauas.girokonto.booking;

import java.time.Instant;

// Eine Zeile in der Umsatzliste, immer aus Sicht EINES Kontos.
// amountCents: + Eingang (grün in der App), − Ausgang (rot in der App).
// counterpartyName: wer auf der anderen Seite steht (Name des Nutzers, bei System-Konten der Kontoname).
// category: kann null sein (z. B. Startguthaben).
public record BookingItemDto(
        Long id,
        Instant bookedAt,
        BookingType type,
        String description,
        long amountCents,
        String counterpartyName,
        String category
) {
}
