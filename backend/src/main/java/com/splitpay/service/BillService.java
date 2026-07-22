package com.splitpay.service;

import com.splitpay.dto.BillDtos.AssignEquallyRequest;
import com.splitpay.dto.BillDtos.AssignMoneyRequest;
import com.splitpay.dto.BillDtos.AssignmentInput;
import com.splitpay.dto.BillDtos.ManualExpenseRequest;
import com.splitpay.dto.BillDtos.ManualItemInput;
import com.splitpay.dto.BillDtos.MarkPaidRequest;
import com.splitpay.dto.BillDtos.PaymentInput;
import com.splitpay.dto.BillDtos.PaymentRequest;
import com.splitpay.exception.ApiException;
import com.splitpay.model.AuditLog;
import com.splitpay.model.Expense;
import com.splitpay.model.Group;
import com.splitpay.model.User;
import com.splitpay.repository.ExpenseRepository;
import com.splitpay.repository.GroupRepository;
import com.splitpay.repository.UserRepository;
import com.splitpay.security.UploadRateLimiter;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Instant;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Bill/expense logic ported from controllers/billController.js: OCR upload + Gemini parse, money
 * and equal assignment, settlement into user balances, payment recording, mark-as-paid, the
 * net-balance split calculation and the settlements list.
 */
@Service
public class BillService {

    private final ExpenseRepository expenseRepository;
    private final GroupRepository groupRepository;
    private final UserRepository userRepository;
    private final BillParserService billParserService;
    private final FileStorageService fileStorageService;
    private final AuditLogService auditLogService;
    private final UploadRateLimiter uploadRateLimiter;

    public BillService(ExpenseRepository expenseRepository, GroupRepository groupRepository,
                       UserRepository userRepository,
                       BillParserService billParserService, FileStorageService fileStorageService,
                       AuditLogService auditLogService, UploadRateLimiter uploadRateLimiter) {
        this.expenseRepository = expenseRepository;
        this.groupRepository = groupRepository;
        this.userRepository = userRepository;
        this.billParserService = billParserService;
        this.fileStorageService = fileStorageService;
        this.auditLogService = auditLogService;
        this.uploadRateLimiter = uploadRateLimiter;
    }

    // ----- queries -------------------------------------------------------------------------

    public List<Expense> getAllBills(String group, String requesterId) {
        if (!StringUtils.hasText(group)) {
            throw ApiException.badRequest("Group ID missing");
        }
        requireGroupMember(group, requesterId);
        return expenseRepository.findByGroupOrderByCreatedAtDesc(group);
    }

    public Expense getBillDetails(String expenseId, String requesterId) {
        if (!StringUtils.hasText(expenseId)) {
            throw ApiException.badRequest("Missing expenseId");
        }
        Expense expense = expenseRepository.findById(expenseId)
                .orElseThrow(() -> ApiException.notFound("Expense not found"));
        requireGroupMember(expense.getGroup(), requesterId);
        return expense;
    }

    // ----- upload + parse ------------------------------------------------------------------

    /**
     * Image → Gemini Vision → persist. Sends the image bytes directly to Gemini so Tesseract
     * OCR is no longer needed. {@code billName} priority: model-detected name → caller-provided
     * name → original filename (no extension) → "Untitled Bill".
     */
    public Expense uploadBill(MultipartFile file, String groupId, String providedBillName, String userId) {
        if (file == null || file.isEmpty()) {
            throw ApiException.badRequest("No file uploaded");
        }
        // Checked before storing the file or calling Gemini so a throttled user doesn't cost us
        // either — each call past this point is a paid Vision API request.
        uploadRateLimiter.checkAndRecord(userId);

        // Store the file first (path traversal + magic-bytes check happens inside store()).
        String storedPath = fileStorageService.store(file);

        // Determine MIME type to pass to Gemini Vision.
        String contentType = file.getContentType();
        String mimeType = (contentType != null && !contentType.isBlank()) ? contentType : "image/jpeg";

        // Read bytes and send directly to Gemini — no OCR step.
        byte[] imageBytes;
        try {
            imageBytes = file.getBytes();
        } catch (IOException e) {
            throw new ApiException(org.springframework.http.HttpStatus.INTERNAL_SERVER_ERROR,
                    "Failed to read uploaded file");
        }

        BillParserService.ParsedBill parsed = billParserService.parseBillImage(imageBytes, mimeType);

        if (parsed == null || parsed.items() == null) {
            throw new ApiException(org.springframework.http.HttpStatus.INTERNAL_SERVER_ERROR,
                    "Failed to parse bill from Gemini");
        }

        BigDecimal total = parsed.total() != null
                ? parsed.total()
                : parsed.items().stream()
                        .map(i -> (i.getPrice() == null ? BigDecimal.ZERO : i.getPrice())
                                .multiply(BigDecimal.valueOf(i.getQuantity() == null ? 1 : i.getQuantity())))
                        .reduce(BigDecimal.ZERO, BigDecimal::add);

        String fallbackFromFilename = stripExtension(file.getOriginalFilename());
        String billName = firstNonBlank(parsed.billName(), providedBillName, fallbackFromFilename, "Untitled Bill");

        Expense expense = Expense.builder()
                .billName(billName)
                .group(groupId)
                .createdBy(userId)
                .billImageUrl(storedPath)
                .totalAmount(total)
                .items(parsed.items())
                .splitMethod("equal")
                .build();
        expense = expenseRepository.save(expense);
        auditLogService.record(expense.getId(), groupId, "UPLOAD_BILL", userId,
                "Uploaded bill '" + billName + "' for ₹" + total.toPlainString());
        return expense;
    }

    // ----- manual create / delete ----------------------------------------------------------

    /**
     * Creates an expense without an image (manual entry). The caller must belong to the group.
     * Items, payments and assignments are taken from the request; member ids referenced by
     * payments/assignments are validated against the group's membership.
     */
    public Expense createManualExpense(ManualExpenseRequest req, String userId) {
        Group group = groupRepository.findById(req.groupId())
                .orElseThrow(() -> ApiException.notFound("Group not found"));
        if (!group.getMembers().contains(userId)) {
            throw ApiException.forbidden("You are not a member of this group");
        }
        Set<String> memberIds = new LinkedHashSet<>(group.getMembers());

        List<Expense.Item> items = new ArrayList<>();
        for (ManualItemInput it : req.items()) {
            List<String> assignedTo = it.assignedTo() == null ? new ArrayList<>() : new ArrayList<>(it.assignedTo());
            for (String memberId : assignedTo) {
                if (!memberIds.contains(memberId)) {
                    throw ApiException.badRequest("assignedTo user " + memberId + " is not a member of the group");
                }
            }
            items.add(Expense.Item.builder()
                    .name(it.name())
                    .quantity(it.quantity() == null ? 1 : it.quantity())
                    .price(it.price())
                    .assignedTo(assignedTo)
                    .build());
        }

        List<Expense.Payment> payments = new ArrayList<>();
        if (req.payments() != null) {
            for (PaymentInput p : req.payments()) {
                if (!memberIds.contains(p.user())) {
                    throw ApiException.badRequest("Payment user " + p.user() + " is not a member of the group");
                }
                payments.add(Expense.Payment.builder()
                        .user(p.user())
                        .amount(p.amount())
                        .method(p.method() != null ? p.method() : "cash")
                        .build());
            }
        }

        List<Expense.Assignment> assignments = new ArrayList<>();
        if (req.assignments() != null) {
            for (AssignmentInput a : req.assignments()) {
                if (!memberIds.contains(a.from()) || !memberIds.contains(a.to())) {
                    throw ApiException.badRequest("Invalid assignment: " + a.from() + " or " + a.to() + " not in group");
                }
                assignments.add(Expense.Assignment.builder()
                        .from(a.from())
                        .to(a.to())
                        .amount(a.amount())
                        .build());
            }
        }

        Expense expense = Expense.builder()
                .billName(req.billName())
                .group(req.groupId())
                .createdBy(userId)
                .totalAmount(req.totalAmount())
                .items(items)
                .payments(payments)
                .assignments(assignments)
                .splitMethod(StringUtils.hasText(req.splitMethod()) ? req.splitMethod() : "equal")
                .build();
        expense = expenseRepository.save(expense);
        auditLogService.record(expense.getId(), req.groupId(), "CREATE_MANUAL_EXPENSE", userId,
                "Created manual expense '" + req.billName() + "' for ₹" + req.totalAmount().toPlainString());
        return expense;
    }

    /**
     * Deletes an expense. Only a member of the expense's group may delete it (the original Node
     * route had no guard; we add a membership check to prevent cross-group deletion).
     */
    public void deleteBill(String expenseId, String requesterId) {
        if (!StringUtils.hasText(expenseId)) {
            throw ApiException.badRequest("Missing expenseId");
        }
        Expense expense = expenseRepository.findById(expenseId)
                .orElseThrow(() -> ApiException.notFound("Expense not found"));
        Group group = groupRepository.findById(expense.getGroup()).orElse(null);
        if (group != null && !group.getMembers().contains(requesterId)) {
            throw ApiException.forbidden("You are not a member of this group");
        }
        expenseRepository.deleteById(expenseId);
        auditLogService.record(expenseId, expense.getGroup(), "DELETE_BILL", requesterId,
                "Deleted expense '" + expense.getBillName() + "' (₹" + expense.getTotalAmount().toPlainString() + ")");
    }

    // ----- assignments ---------------------------------------------------------------------

    /** Money-only assignment (assignMoney). Validates from/to are members and amount is numeric. */
    public Expense assignMoney(AssignMoneyRequest req, String requesterId) {
        Expense expense = expenseRepository.findById(req.expenseId())
                .orElseThrow(() -> ApiException.notFound("expense not found"));

        Group group = groupRepository.findById(expense.getGroup())
                .orElseThrow(() -> ApiException.notFound("Group not found"));
        if (!group.getMembers().contains(requesterId)) {
            throw ApiException.forbidden("You are not a member of this group");
        }
        Set<String> memberIds = new LinkedHashSet<>(group.getMembers());

        for (AssignmentInput a : req.assignments()) {
            if (!memberIds.contains(a.from()) || !memberIds.contains(a.to())) {
                throw ApiException.badRequest("Invalid assignment: " + a.from() + " or " + a.to() + " not in group");
            }
        }

        List<Expense.Assignment> assignments = new ArrayList<>();
        for (AssignmentInput a : req.assignments()) {
            assignments.add(Expense.Assignment.builder()
                    .from(a.from())
                    .to(a.to())
                    .amount(a.amount())
                    .build());
        }
        expense.setAssignments(assignments);
        expense.setSplitMethod("money");
        expense = expenseRepository.save(expense);
        auditLogService.record(expense.getId(), group.getId(), "ASSIGN_MONEY", requesterId,
                "Set " + assignments.size() + " manual money assignment(s)");
        return expense;
    }

    /** Equal split among the supplied userIds, with everyone owing the payer (assignEqually). */
    public Expense assignEqually(AssignEquallyRequest req, String requesterId) {
        Group group = groupRepository.findById(req.groupId())
                .orElseThrow(() -> ApiException.notFound("Group not found"));
        if (!group.getMembers().contains(requesterId)) {
            throw ApiException.forbidden("You are not a member of this group");
        }
        Set<String> memberIds = new LinkedHashSet<>(group.getMembers());
        for (String id : req.userIds()) {
            if (!memberIds.contains(id)) {
                throw ApiException.badRequest("User " + id + " is not a member of the group");
            }
        }
        Expense expense = expenseRepository.findById(req.expenseId())
                .orElseThrow(() -> ApiException.notFound("Expense not found"));

        int n = req.userIds().size();
        BigDecimal total = expense.getTotalAmount();
        // BigDecimal division to a fixed scale is exact — no floating-point drift to patch up.
        // A per-cent remainder is still mathematically unavoidable when total/n doesn't divide
        // evenly (e.g. $10.00 / 3), so it's deliberately assigned in full to the last debtor,
        // rather than corrected for after the fact.
        BigDecimal base = total.divide(BigDecimal.valueOf(n), 2, RoundingMode.HALF_UP);
        BigDecimal sumOfBase = base.multiply(BigDecimal.valueOf(n - 1)); // n-1 debtors (payer excluded)
        BigDecimal remainder = total.subtract(sumOfBase).subtract(base); // payer's own share delta

        List<Expense.Assignment> assignments = new ArrayList<>();
        List<String> debtors = req.userIds().stream()
                .filter(id -> !id.equals(req.paidBy()))
                .toList();
        for (int i = 0; i < debtors.size(); i++) {
            BigDecimal amount = (i == debtors.size() - 1)
                    ? base.add(remainder)
                    : base;
            assignments.add(Expense.Assignment.builder()
                    .from(debtors.get(i))
                    .to(req.paidBy())
                    .amount(amount)
                    .build());
        }
        expense.setAssignments(assignments);
        expense.setSplitMethod("equal");
        expense = expenseRepository.save(expense);
        auditLogService.record(expense.getId(), group.getId(), "ASSIGN_EQUALLY", requesterId,
                "Split equally among " + n + " member(s), paid by " + req.paidBy());
        return expense;
    }

    // ----- settlement / payment ------------------------------------------------------------

    /** Rolls each assignment into the from/to users' running balances (settleAssignments). */
    public Expense settleAssignments(String expenseId, String requesterId) {
        if (!StringUtils.hasText(expenseId)) {
            throw ApiException.badRequest("Missing expenseId");
        }
        Expense expense = expenseRepository.findById(expenseId)
                .orElseThrow(() -> ApiException.notFound("Expense not found"));
        Group group = groupRepository.findById(expense.getGroup())
                .orElseThrow(() -> ApiException.notFound("Group not found"));
        if (!group.getMembers().contains(requesterId)) {
            throw ApiException.forbidden("You are not a member of this group");
        }

        for (Expense.Assignment a : expense.getAssignments()) {
            if (a == null || a.getAmount() == null || a.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
                continue;
            }
            String fromId = a.getFrom();
            String toId = a.getTo();
            if (fromId == null || toId == null || fromId.equals(toId)) {
                continue;
            }
            userRepository.findById(toId).ifPresent(u -> {
                u.setYouAreOwed(u.getYouAreOwed().add(a.getAmount()));
                userRepository.save(u);
            });
            userRepository.findById(fromId).ifPresent(u -> {
                u.setYouOwe(u.getYouOwe().add(a.getAmount()));
                userRepository.save(u);
            });
        }
        auditLogService.record(expense.getId(), expense.getGroup(), "SETTLE_ASSIGNMENTS", requesterId,
                "Settled assignments into running balances");
        return expense;
    }

    /**
     * Records a payment against an expense (recordPayment).
     *
     * <p>NOTE: the original Node controller crashed here — it referenced an undefined
     * {@code UpdatedinUser} variable (its assignment was commented out), so the route always threw.
     * We implement the clear intent: validate membership, append the payment, persist, and return
     * the saved expense. No balance mutation is done here (that is settleAssignments' job), matching
     * what the commented-out code would have skipped.
     */
    public Expense recordPayment(PaymentRequest req, String requesterId) {
        String payerId = req.paidBy() != null ? req.paidBy() : requesterId;
        Expense expense = expenseRepository.findById(req.expenseId())
                .orElseThrow(() -> ApiException.notFound("Expense not found"));
        Group group = groupRepository.findById(expense.getGroup())
                .orElseThrow(() -> ApiException.notFound("Group not found"));

        List<String> memberIds = group.getMembers();
        if (!memberIds.contains(requesterId)) {
            throw ApiException.forbidden("You are not a member of this group");
        }
        if (!memberIds.contains(payerId)) {
            throw ApiException.badRequest("The specified payer is not a member of this group");
        }

        expense.getPayments().add(Expense.Payment.builder()
                .user(payerId)
                .amount(req.amount())
                .method(req.method() != null ? req.method() : "cash")
                .build());
        expense = expenseRepository.save(expense);
        auditLogService.record(expense.getId(), group.getId(), "RECORD_PAYMENT", requesterId,
                "Recorded payment of ₹" + req.amount().toPlainString() + " by user " + payerId);
        return expense;
    }

    /** Decrements an assignment by the amount paid, flips isPaid, and adjusts balances (markAssignmentPaid). */
    public Expense markAssignmentPaid(MarkPaidRequest req, String currentUserId) {
        Expense expense = expenseRepository.findById(req.expenseId())
                .orElseThrow(() -> ApiException.notFound("Expense not found"));

        Expense.Assignment assignment = expense.getAssignments().stream()
                .filter(a -> req.assignmentId().equals(a.getId()))
                .findFirst()
                .orElseThrow(() -> ApiException.notFound("Assignment not found"));

        // Only the payee ("to") may mark a debt as paid, matching the original authorization check.
        if (!currentUserId.equals(assignment.getTo())) {
            throw ApiException.badRequest("You are not authorized to mark this as paid");
        }

        BigDecimal amountPaid = req.amountPaid();
        BigDecimal remaining = (assignment.getAmount() == null ? BigDecimal.ZERO : assignment.getAmount())
                .subtract(amountPaid);
        assignment.setAmount(remaining);
        boolean paid = remaining.compareTo(BigDecimal.ZERO) <= 0;
        assignment.setPaid(paid);
        if (paid) {
            assignment.setPaidAt(Instant.now());
        }
        expenseRepository.save(expense);

        userRepository.findById(assignment.getFrom()).ifPresent(ower ->
                userRepository.findById(assignment.getTo()).ifPresent(receiver -> {
                    ower.setYouOwe(ower.getYouOwe().subtract(amountPaid).max(BigDecimal.ZERO));
                    receiver.setYouAreOwed(receiver.getYouAreOwed().subtract(amountPaid).max(BigDecimal.ZERO));
                    userRepository.save(ower);
                    userRepository.save(receiver);
                }));
        auditLogService.record(expense.getId(), expense.getGroup(), "MARK_ASSIGNMENT_PAID", currentUserId,
                "Marked ₹" + amountPaid.toPlainString() + " paid on assignment " + req.assignmentId());
        return expense;
    }

    // ----- split calculation ---------------------------------------------------------------

    /**
     * Net-balance settlement calculation (splitExpense).
     *
     * <p>The original iterated {@code assignments.user} and {@code payments.user}. The assignment
     * subdocument has no {@code user} field (it has from/to), so in practice only payments
     * contributed to the assigned/paid maps in the Node code. We preserve that behaviour: paid is
     * summed from payments; assigned stays empty (no per-user assignment field exists). The greedy
     * debtor→creditor settlement matching is identical.
     */
    public Map<String, Object> splitExpense(String expenseId, String requesterId) {
        Expense expense = expenseRepository.findById(expenseId)
                .orElseThrow(() -> ApiException.notFound("Expense not found"));
        requireGroupMember(expense.getGroup(), requesterId);

        Map<String, BigDecimal> paidMap = new LinkedHashMap<>();
        for (Expense.Payment p : expense.getPayments()) {
            if (p.getUser() == null) {
                continue;
            }
            paidMap.merge(p.getUser(), p.getAmount() == null ? BigDecimal.ZERO : p.getAmount(), BigDecimal::add);
        }

        List<Map<String, Object>> perUser = new ArrayList<>();
        for (Map.Entry<String, BigDecimal> entry : paidMap.entrySet()) {
            User u = userRepository.findById(entry.getKey()).orElse(null);
            BigDecimal paid = entry.getValue();
            Map<String, Object> row = new LinkedHashMap<>();
            row.put("userId", entry.getKey());
            row.put("name", u != null ? u.getName() : "Unknown");
            row.put("email", u != null ? u.getEmail() : "");
            row.put("assigned", BigDecimal.ZERO);
            row.put("paid", paid);
            row.put("net", paid); // net = paid - assigned, assigned is 0
            perUser.add(row);
        }

        // Greedy debtor -> creditor matching (debtors have net < 0; with assigned=0 there are none,
        // but the logic is kept intact to match the original).
        List<Map<String, Object>> debtors = perUser.stream()
                .filter(u -> ((BigDecimal) u.get("net")).compareTo(BigDecimal.ZERO) < 0).toList();
        List<Map<String, Object>> creditors = perUser.stream()
                .filter(u -> ((BigDecimal) u.get("net")).compareTo(BigDecimal.ZERO) > 0).toList();
        List<Map<String, Object>> settlements = new ArrayList<>();

        for (Map<String, Object> debtor : debtors) {
            BigDecimal amountToSettle = ((BigDecimal) debtor.get("net")).abs();
            for (Map<String, Object> creditor : creditors) {
                if (amountToSettle.compareTo(BigDecimal.ZERO) <= 0) {
                    break;
                }
                BigDecimal creditorNet = (BigDecimal) creditor.get("net");
                BigDecimal payAmount = amountToSettle.min(creditorNet);
                if (payAmount.compareTo(BigDecimal.ZERO) > 0) {
                    Map<String, Object> s = new LinkedHashMap<>();
                    s.put("from", debtor.get("name"));
                    s.put("to", creditor.get("name"));
                    s.put("amount", payAmount);
                    settlements.add(s);
                    debtor.put("net", ((BigDecimal) debtor.get("net")).add(payAmount));
                    creditor.put("net", creditorNet.subtract(payAmount));
                    amountToSettle = amountToSettle.subtract(payAmount);
                }
            }
        }

        Map<String, Object> result = new LinkedHashMap<>();
        result.put("totalAmount", expense.getTotalAmount());
        result.put("splitMethod", expense.getSplitMethod());
        result.put("perUser", perUser);
        result.put("settlements", settlements);
        return result;
    }

    /**
     * Flattened list of all assignments across a group's expenses (Settlements). Self-assignments
     * (from == to) are filtered out. The from/to are returned as raw id strings, matching the
     * original (which did not populate them).
     */
    public List<Map<String, Object>> settlements(String group, String requesterId) {
        if (!StringUtils.hasText(group)) {
            throw ApiException.badRequest("Group ID missing");
        }
        requireGroupMember(group, requesterId);
        List<Expense> expenses = expenseRepository.findByGroup(group);
        if (expenses.isEmpty()) {
            throw ApiException.notFound("The bill (expense) doesn't exist");
        }
        List<Map<String, Object>> all = new ArrayList<>();
        for (Expense exp : expenses) {
            for (Expense.Assignment a : exp.getAssignments()) {
                if (a.getFrom() != null && a.getFrom().equals(a.getTo())) {
                    continue;
                }
                Map<String, Object> m = new LinkedHashMap<>();
                m.put("_id", a.getId());
                m.put("from", a.getFrom());
                m.put("to", a.getTo());
                m.put("amount", a.getAmount());
                m.put("expenseId", exp.getId());
                m.put("isPaid", a.isPaid());
                m.put("paidAt", a.getPaidAt());
                all.add(m);
            }
        }
        return all;
    }

    /** Audit trail for an expense, newest first — who assigned/paid/deleted what, for disputes. */
    public List<AuditLog> getAuditTrail(String expenseId, String requesterId) {
        if (!StringUtils.hasText(expenseId)) {
            throw ApiException.badRequest("Missing expenseId");
        }
        Expense expense = expenseRepository.findById(expenseId).orElse(null);
        // DELETE_BILL entries outlive the expense itself, so fall back to the group recorded on
        // the most recent log entry when the expense no longer exists.
        if (expense != null) {
            requireGroupMember(expense.getGroup(), requesterId);
        } else {
            List<AuditLog> existing = auditLogService.forExpense(expenseId);
            if (!existing.isEmpty()) {
                requireGroupMember(existing.get(0).getGroupId(), requesterId);
            }
            return existing;
        }
        return auditLogService.forExpense(expenseId);
    }

    // ----- helpers -------------------------------------------------------------------------

    /** Throws forbidden unless requesterId is a member of the given group. */
    private void requireGroupMember(String groupId, String requesterId) {
        Group group = groupRepository.findById(groupId)
                .orElseThrow(() -> ApiException.notFound("Group not found"));
        if (!group.getMembers().contains(requesterId)) {
            throw ApiException.forbidden("You are not a member of this group");
        }
    }

    private static String stripExtension(String filename) {
        if (filename == null) {
            return "";
        }
        return filename.replaceFirst("\\.[^/.]+$", "").trim();
    }

    private static String firstNonBlank(String... values) {
        for (String v : values) {
            if (v != null && !v.trim().isEmpty()) {
                return v.trim();
            }
        }
        return "";
    }
}
