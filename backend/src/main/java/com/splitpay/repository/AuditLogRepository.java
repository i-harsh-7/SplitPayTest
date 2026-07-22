package com.splitpay.repository;

import com.splitpay.model.AuditLog;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.List;

public interface AuditLogRepository extends MongoRepository<AuditLog, String> {

    List<AuditLog> findByExpenseIdOrderByCreatedAtDesc(String expenseId);
}
