package com.splitpay.model;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

import java.time.Instant;

/**
 * An append-only record of who performed a financial mutation (assignment, payment, deletion) on
 * an expense, for dispute resolution. Nothing in the app ever updates or deletes an entry.
 */
@Document(collection = "audit_logs")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AuditLog {

    @Id
    private String id;

    /** The expense this mutation applies to. Kept even after the expense itself is deleted. */
    @Indexed
    private String expenseId;

    @Indexed
    private String groupId;

    /** ASSIGN_MONEY | ASSIGN_EQUALLY | RECORD_PAYMENT | MARK_ASSIGNMENT_PAID | SETTLE_ASSIGNMENTS
     *  | CREATE_MANUAL_EXPENSE | UPLOAD_BILL | DELETE_BILL */
    private String action;

    /** User id who performed the action. */
    private String performedBy;

    /** Human-readable summary, e.g. "Marked ₹250.00 paid on assignment 64f...". */
    private String summary;

    @CreatedDate
    private Instant createdAt;
}
