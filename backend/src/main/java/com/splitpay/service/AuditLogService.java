package com.splitpay.service;

import com.splitpay.model.AuditLog;
import com.splitpay.repository.AuditLogRepository;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Append-only audit trail for financial mutations (assignments, payments, deletions), so a dispute
 * over "who changed this" has an answer. Logging is best-effort: a failure here never blocks the
 * financial operation it's recording, matching how NotificationService treats its own writes.
 */
@Service
public class AuditLogService {

    private final AuditLogRepository auditLogRepository;

    public AuditLogService(AuditLogRepository auditLogRepository) {
        this.auditLogRepository = auditLogRepository;
    }

    public void record(String expenseId, String groupId, String action, String performedBy, String summary) {
        try {
            auditLogRepository.save(AuditLog.builder()
                    .expenseId(expenseId)
                    .groupId(groupId)
                    .action(action)
                    .performedBy(performedBy)
                    .summary(summary)
                    .build());
        } catch (Exception ignored) {
            // Best-effort: never fail the parent financial operation because logging it failed.
        }
    }

    public List<AuditLog> forExpense(String expenseId) {
        return auditLogRepository.findByExpenseIdOrderByCreatedAtDesc(expenseId);
    }
}
