package com.splitpay.model;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;
import org.bson.types.ObjectId;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.Id;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.mongodb.core.mapping.Document;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;

/**
 * Mirrors the Mongoose Expense schema (models/expense.js), including the nested
 * item / payment / assignment subdocuments.
 *
 * <p>References ({@code group}, {@code createdBy}, item/assignment/payment user fields) are stored
 * as id strings and populated at the mapper layer to reproduce Mongoose's {@code .populate(...)}.
 */
@Document(collection = "expenses")
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class Expense {

    @Id
    private String id;

    private String billName;

    /** Group id reference. */
    private String group;

    /** Creator User id reference. */
    private String createdBy;

    private String billImageUrl;

    @Builder.Default
    private List<Item> items = new ArrayList<>();

    /** "equal" | "per-item" | "money" — defaults to "equal" like the schema. */
    @Builder.Default
    private String splitMethod = "equal";

    @Builder.Default
    private BigDecimal totalAmount = BigDecimal.ZERO;

    @Builder.Default
    private List<Payment> payments = new ArrayList<>();

    @Builder.Default
    private List<Assignment> assignments = new ArrayList<>();

    @Builder.Default
    private List<SplitSummary> splitSummary = new ArrayList<>();

    @CreatedDate
    private Instant createdAt;

    @LastModifiedDate
    private Instant updatedAt;

    // ----- nested subdocuments -------------------------------------------------------------

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Item {
        private String name;
        private BigDecimal price;
        @Builder.Default
        private Integer quantity = 1;
        /** User id references. */
        @Builder.Default
        private List<String> assignedTo = new ArrayList<>();
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Payment {
        /** Serialized as "_id" so the Flutter client sees a Mongo-style subdocument id. */
        @JsonProperty("_id")
        @Builder.Default
        private String id = new ObjectId().toHexString();
        /** Payer User id reference. */
        private String user;
        private BigDecimal amount;
        /** optional (UPI, cash, card...) */
        private String method;
        @Builder.Default
        private Instant createdAt = Instant.now();
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class Assignment {
        /**
         * Subdocument id. Mongoose auto-generates an {@code _id} for every array subdocument and the
         * Flutter client reads it (e.g. as {@code assignmentId} when marking paid, and as
         * {@code _id} in the settlements list), so we generate one too and serialize it as "_id".
         */
        @JsonProperty("_id")
        @Builder.Default
        private String id = new ObjectId().toHexString();
        /** User id reference — who owes money. */
        private String from;
        /** User id reference — who should be paid. */
        private String to;
        private BigDecimal amount;
        /**
         * Explicit JSON name: Lombok's getter for a boolean named {@code isPaid} is {@code isPaid()},
         * which Jackson would otherwise expose as "paid". The Flutter client reads "isPaid".
         */
        @JsonProperty("isPaid")
        @Builder.Default
        private boolean isPaid = false;
        private Instant paidAt;
    }

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class SplitSummary {
        /** User id reference. */
        private String userId;
        private BigDecimal amountOwed;
    }
}
