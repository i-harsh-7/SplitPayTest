package com.splitpay.repository;

import com.splitpay.model.Expense;
import org.springframework.data.mongodb.repository.MongoRepository;

import java.util.List;

public interface ExpenseRepository extends MongoRepository<Expense, String> {

    /** All expenses for a group, newest first (matches {@code .sort({ createdAt: -1 })}). */
    List<Expense> findByGroupOrderByCreatedAtDesc(String group);

    List<Expense> findByGroup(String group);

    /** Removes all expenses belonging to a group (used when the group is deleted). */
    void deleteByGroup(String group);
}
