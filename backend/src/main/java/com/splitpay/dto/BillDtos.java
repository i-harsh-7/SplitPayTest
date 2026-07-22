package com.splitpay.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;
import jakarta.validation.constraints.PositiveOrZero;

import java.math.BigDecimal;
import java.util.List;

/**
 * Request bodies for the bill/expense endpoints. Field names mirror exactly what the Express
 * controllers destructured from {@code req.body}. Validated declaratively via {@code @Valid} at
 * the controller boundary; {@code @Valid} on a nested list cascades these constraints onto every
 * element.
 */
public final class BillDtos {

    private BillDtos() {
    }

    /** One entry in the assignments array of assign-money. */
    public record AssignmentInput(
            @NotBlank(message = "Assignment 'from' user is required") String from,
            @NotBlank(message = "Assignment 'to' user is required") String to,
            @NotNull(message = "Assignment amount is required") @Positive(message = "Assignment amount must be greater than zero") BigDecimal amount) {
    }

    /** Body for PATCH /bills/assign-money. */
    public record AssignMoneyRequest(
            @NotBlank(message = "expenseId is required") String expenseId,
            @NotEmpty(message = "At least one assignment is required") @Valid List<AssignmentInput> assignments) {
    }

    /** Body for PATCH /bills/assign-Equally. */
    public record AssignEquallyRequest(
            @NotBlank(message = "expenseId is required") String expenseId,
            @NotEmpty(message = "At least one userId is required") List<@NotBlank(message = "userId cannot be blank") String> userIds,
            @NotBlank(message = "paidBy is required") String paidBy,
            @NotBlank(message = "groupId is required") String groupId) {
    }

    /** Body for POST /bills/settleAssignment. */
    public record SettleRequest(@NotBlank(message = "expenseId is required") String expenseId) {
    }

    /** Body for POST /bills/payment. */
    public record PaymentRequest(
            @NotBlank(message = "expenseId is required") String expenseId,
            @NotNull(message = "amount is required") @Positive(message = "amount must be greater than zero") BigDecimal amount,
            String method,
            String paidBy) {
    }

    /** Body for POST /bills/markAsPaid. */
    public record MarkPaidRequest(
            @NotBlank(message = "expenseId is required") String expenseId,
            @NotBlank(message = "assignmentId is required") String assignmentId,
            @NotNull(message = "amountPaid is required") @Positive(message = "amountPaid must be greater than zero") BigDecimal amountPaid) {
    }

    /** Body for GET-style group lookups that take { group } (getAllBills, getAssignments). */
    public record GroupBodyRequest(String group) {
    }

    /** One item in a manual expense (manual bill entry). */
    public record ManualItemInput(
            @NotBlank(message = "Item name is required") String name,
            @Positive(message = "Item quantity must be greater than zero") Integer quantity,
            @NotNull(message = "Item price is required") @PositiveOrZero(message = "Item price cannot be negative") BigDecimal price,
            List<@NotBlank(message = "assignedTo entries cannot be blank") String> assignedTo) {
    }

    /** A payment line for a manual expense: { user, amount, method? }. */
    public record PaymentInput(
            @NotBlank(message = "Payment user is required") String user,
            @NotNull(message = "Payment amount is required") @Positive(message = "Payment amount must be greater than zero") BigDecimal amount,
            String method) {
    }

    /**
     * Body for POST /bills/manual. Mirrors what the Flutter client's createManualExpense sends:
     * groupId, totalAmount, items, billName, and optional splitMethod / payments / assignments.
     */
    public record ManualExpenseRequest(
            @NotBlank(message = "groupId is required") String groupId,
            @NotNull(message = "totalAmount is required") @Positive(message = "totalAmount must be greater than zero") BigDecimal totalAmount,
            @NotEmpty(message = "At least one item is required") @Valid List<ManualItemInput> items,
            @NotBlank(message = "billName is required") String billName,
            String splitMethod,
            @Valid List<PaymentInput> payments,
            @Valid List<AssignmentInput> assignments) {
    }

    /** Body for DELETE /bills/deleteBill, which the client sends as { expenseId }. */
    public record DeleteBillRequest(@NotBlank(message = "expenseId is required") String expenseId) {
    }
}
