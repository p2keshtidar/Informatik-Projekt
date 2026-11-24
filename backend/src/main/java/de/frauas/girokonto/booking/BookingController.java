package de.frauas.girokonto.booking;

import de.frauas.girokonto.auth.AuthUser;
import de.frauas.girokonto.common.ApiError;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;

import java.time.Instant;
import java.time.LocalDate;

// Umsätze und Buchungsdetails. Der Nutzer kommt immer aus dem Token, nie aus der URL.
@RestController
public class BookingController {

    private final BookingQueryService queryService;

    public BookingController(BookingQueryService queryService) {
        this.queryService = queryService;
    }

    // GET /api/accounts/5/bookings?from=2026-12-01&to=2026-12-31&minCents=1000&maxCents=50000&q=miete&page=0&size=20
    @GetMapping("/api/accounts/{accountId}/bookings")
    public BookingQueryService.Page bookings(
            @AuthenticationPrincipal AuthUser me,
            @PathVariable Long accountId,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate to,
            @RequestParam(required = false) Long minCents,
            @RequestParam(required = false) Long maxCents,
            @RequestParam(required = false) String q,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "" + BookingQueryService.DEFAULT_SIZE) int size) {
        return queryService.bookingsOf(me.id(), accountId,
                new BookingQueryService.Filter(from, to, minCents, maxCents, q), page, size);
    }

    // GET /api/bookings/42 → Buchung mit allen Zeilen
    @GetMapping("/api/bookings/{bookingId}")
    public BookingQueryService.Detail booking(@AuthenticationPrincipal AuthUser me, @PathVariable Long bookingId) {
        return queryService.booking(me.id(), bookingId);
    }

    // z. B. from=gestern oder minCents=abc: sonst käme 500 statt 400
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    public ResponseEntity<ApiError> badParameter(MethodArgumentTypeMismatchException ex, HttpServletRequest req) {
        HttpStatus status = HttpStatus.BAD_REQUEST;
        return ResponseEntity.status(status).body(new ApiError(Instant.now(), status.value(), status.getReasonPhrase(),
                "Ungültiger Wert für " + ex.getName(), req.getRequestURI(), null));
    }
}
