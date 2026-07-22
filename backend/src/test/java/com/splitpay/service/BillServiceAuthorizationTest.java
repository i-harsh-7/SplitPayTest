package com.splitpay.service;

import com.splitpay.dto.BillDtos.AssignEquallyRequest;
import com.splitpay.dto.BillDtos.AssignMoneyRequest;
import com.splitpay.dto.BillDtos.AssignmentInput;
import com.splitpay.exception.ApiException;
import com.splitpay.model.Expense;
import com.splitpay.model.Group;
import com.splitpay.repository.ExpenseRepository;
import com.splitpay.repository.GroupRepository;
import com.splitpay.repository.UserRepository;
import com.splitpay.security.UploadRateLimiter;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

/**
 * Regression tests for the group-membership checks added to BillService: a logged-in user who
 * isn't in the expense's group must be rejected, not just users who fail the from/to/payer checks
 * within an otherwise-valid group. These pin down the IDOR fixes so a future change can't silently
 * drop the {@code requireGroupMember}/{@code group.getMembers().contains(requesterId)} calls.
 */
@ExtendWith(MockitoExtension.class)
class BillServiceAuthorizationTest {

    private static final String GROUP_ID = "group-1";
    private static final String EXPENSE_ID = "expense-1";
    private static final String MEMBER_A = "user-a";
    private static final String MEMBER_B = "user-b";
    private static final String OUTSIDER = "user-outsider";

    @Mock private ExpenseRepository expenseRepository;
    @Mock private GroupRepository groupRepository;
    @Mock private UserRepository userRepository;
    @Mock private BillParserService billParserService;
    @Mock private FileStorageService fileStorageService;
    @Mock private AuditLogService auditLogService;
    @Mock private UploadRateLimiter uploadRateLimiter;

    private BillService billService;
    private Group group;
    private Expense expense;

    @BeforeEach
    void setUp() {
        billService = new BillService(expenseRepository, groupRepository, userRepository,
                billParserService, fileStorageService, auditLogService, uploadRateLimiter);

        group = Group.builder()
                .id(GROUP_ID)
                .name("Roommates")
                .members(List.of(MEMBER_A, MEMBER_B))
                .createdBy(MEMBER_A)
                .build();

        expense = Expense.builder()
                .id(EXPENSE_ID)
                .billName("Dinner")
                .group(GROUP_ID)
                .totalAmount(new BigDecimal("100.00"))
                .build();
    }

    @Test
    void getBillDetails_rejectsNonMember() {
        when(expenseRepository.findById(EXPENSE_ID)).thenReturn(Optional.of(expense));
        when(groupRepository.findById(GROUP_ID)).thenReturn(Optional.of(group));

        assertThatThrownBy(() -> billService.getBillDetails(EXPENSE_ID, OUTSIDER))
                .isInstanceOf(ApiException.class)
                .extracting(ex -> ((ApiException) ex).getStatus())
                .isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void getBillDetails_allowsMember() {
        when(expenseRepository.findById(EXPENSE_ID)).thenReturn(Optional.of(expense));
        when(groupRepository.findById(GROUP_ID)).thenReturn(Optional.of(group));

        Expense result = billService.getBillDetails(EXPENSE_ID, MEMBER_A);

        assertThat(result).isSameAs(expense);
    }

    @Test
    void splitExpense_rejectsNonMember() {
        expense.setPayments(List.of());
        when(expenseRepository.findById(EXPENSE_ID)).thenReturn(Optional.of(expense));
        when(groupRepository.findById(GROUP_ID)).thenReturn(Optional.of(group));

        assertThatThrownBy(() -> billService.splitExpense(EXPENSE_ID, OUTSIDER))
                .isInstanceOf(ApiException.class)
                .extracting(ex -> ((ApiException) ex).getStatus())
                .isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void getAllBills_rejectsNonMember() {
        when(groupRepository.findById(GROUP_ID)).thenReturn(Optional.of(group));

        assertThatThrownBy(() -> billService.getAllBills(GROUP_ID, OUTSIDER))
                .isInstanceOf(ApiException.class)
                .extracting(ex -> ((ApiException) ex).getStatus())
                .isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void settlements_rejectsNonMember() {
        when(groupRepository.findById(GROUP_ID)).thenReturn(Optional.of(group));

        assertThatThrownBy(() -> billService.settlements(GROUP_ID, OUTSIDER))
                .isInstanceOf(ApiException.class)
                .extracting(ex -> ((ApiException) ex).getStatus())
                .isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void assignMoney_rejectsRequesterWhoIsNotAGroupMember_evenWhenFromToAreValidMembers() {
        AssignMoneyRequest req = new AssignMoneyRequest(EXPENSE_ID,
                List.of(new AssignmentInput(MEMBER_A, MEMBER_B, new BigDecimal("25.00"))));
        when(expenseRepository.findById(EXPENSE_ID)).thenReturn(Optional.of(expense));
        when(groupRepository.findById(GROUP_ID)).thenReturn(Optional.of(group));

        assertThatThrownBy(() -> billService.assignMoney(req, OUTSIDER))
                .isInstanceOf(ApiException.class)
                .extracting(ex -> ((ApiException) ex).getStatus())
                .isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void assignMoney_allowsGroupMember() {
        AssignMoneyRequest req = new AssignMoneyRequest(EXPENSE_ID,
                List.of(new AssignmentInput(MEMBER_A, MEMBER_B, new BigDecimal("25.00"))));
        when(expenseRepository.findById(EXPENSE_ID)).thenReturn(Optional.of(expense));
        when(groupRepository.findById(GROUP_ID)).thenReturn(Optional.of(group));
        when(expenseRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        Expense result = billService.assignMoney(req, MEMBER_A);

        assertThat(result.getAssignments()).hasSize(1);
        assertThat(result.getSplitMethod()).isEqualTo("money");
    }

    @Test
    void assignEqually_rejectsRequesterWhoIsNotAGroupMember() {
        AssignEquallyRequest req = new AssignEquallyRequest(
                EXPENSE_ID, List.of(MEMBER_A, MEMBER_B), MEMBER_A, GROUP_ID);
        when(groupRepository.findById(GROUP_ID)).thenReturn(Optional.of(group));

        assertThatThrownBy(() -> billService.assignEqually(req, OUTSIDER))
                .isInstanceOf(ApiException.class)
                .extracting(ex -> ((ApiException) ex).getStatus())
                .isEqualTo(HttpStatus.FORBIDDEN);
    }

    @Test
    void deleteBill_rejectsNonMember() {
        when(expenseRepository.findById(EXPENSE_ID)).thenReturn(Optional.of(expense));
        when(groupRepository.findById(GROUP_ID)).thenReturn(Optional.of(group));

        assertThatThrownBy(() -> billService.deleteBill(EXPENSE_ID, OUTSIDER))
                .isInstanceOf(ApiException.class)
                .extracting(ex -> ((ApiException) ex).getStatus())
                .isEqualTo(HttpStatus.FORBIDDEN);
    }
}
