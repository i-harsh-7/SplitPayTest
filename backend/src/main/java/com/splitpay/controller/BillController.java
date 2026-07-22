package com.splitpay.controller;

import com.splitpay.dto.BillDtos.AssignEquallyRequest;
import com.splitpay.dto.BillDtos.AssignMoneyRequest;
import com.splitpay.dto.BillDtos.DeleteBillRequest;
import com.splitpay.dto.BillDtos.GroupBodyRequest;
import com.splitpay.dto.BillDtos.ManualExpenseRequest;
import com.splitpay.dto.BillDtos.MarkPaidRequest;
import com.splitpay.dto.BillDtos.PaymentRequest;
import com.splitpay.dto.BillDtos.SettleRequest;
import com.splitpay.exception.ApiException;
import com.splitpay.model.Expense;
import com.splitpay.security.CurrentUser;
import com.splitpay.service.BillService;
import com.splitpay.service.FileStorageService;
import com.splitpay.service.ResponseMapper;
import com.splitpay.web.ApiResponse;
import jakarta.validation.Valid;
import org.springframework.core.io.Resource;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.util.StringUtils;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;
import java.util.Map;

/**
 * Bill/expense endpoints under /api/v1/bills, matching billRoutes.js.
 *
 * <p>For {@code getAllBills} and {@code getAssignments} the original declared GET routes that read
 * the group id from the request body; the Flutter client sends it as a {@code ?group=} query param.
 * Both are accepted here so either caller works.
 */
@RestController
@RequestMapping("/api/v1/bills")
public class BillController {

    private final BillService billService;
    private final ResponseMapper responseMapper;
    private final FileStorageService fileStorageService;

    public BillController(BillService billService, ResponseMapper responseMapper,
                          FileStorageService fileStorageService) {
        this.billService = billService;
        this.responseMapper = responseMapper;
        this.fileStorageService = fileStorageService;
    }

    @PostMapping("/upload")
    public ResponseEntity<?> uploadBill(@RequestParam("bill") MultipartFile bill,
                                        @RequestParam(value = "groupId", required = false) String groupId,
                                        @RequestParam(value = "billName", required = false) String billName) {
        Expense expense = billService.uploadBill(bill, groupId, billName, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Bill uploaded, parsed, and saved successfully")
                .with("expense", responseMapper.populateExpense(expense)));
    }

    @PostMapping("/manual")
    public ResponseEntity<?> createManualExpense(@Valid @RequestBody ManualExpenseRequest req) {
        Expense expense = billService.createManualExpense(req, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Expense created successfully")
                .with("expense", responseMapper.populateExpense(expense)));
    }

    @GetMapping("/getBillDetails/{expenseId}")
    public ResponseEntity<?> getBillDetails(@PathVariable String expenseId) {
        Expense expense = billService.getBillDetails(expenseId, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Expense details fetched successfully")
                .with("expense", responseMapper.populateExpense(expense)));
    }

    @PatchMapping("/assign-money")
    public ResponseEntity<?> assignMoney(@Valid @RequestBody AssignMoneyRequest req) {
        Expense expense = billService.assignMoney(req, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("assigned money successfully to the members")
                .with("expense", responseMapper.populateExpense(expense)));
    }

    @PatchMapping("/assign-Equally")
    public ResponseEntity<?> assignEqually(@Valid @RequestBody AssignEquallyRequest req) {
        Expense expense = billService.assignEqually(req, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Expense assigned equally successfully")
                .with("expense", responseMapper.populateExpense(expense)));
    }

    @PostMapping("/settleAssignment")
    public ResponseEntity<?> settleAssignment(@Valid @RequestBody SettleRequest req) {
        Expense expense = billService.settleAssignments(req.expenseId(), CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Assignments settled successfully")
                .with("expense", responseMapper.populateExpense(expense)));
    }

    @PostMapping("/markAsPaid")
    public ResponseEntity<?> markAsPaid(@Valid @RequestBody MarkPaidRequest req) {
        Expense expense = billService.markAssignmentPaid(req, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Assignment marked as paid")
                .with("expense", responseMapper.populateExpense(expense)));
    }

    @GetMapping("/getAssignments")
    public ResponseEntity<?> getAssignments(@RequestParam(value = "group", required = false) String groupParam,
                                            @RequestBody(required = false) GroupBodyRequest body) {
        String group = StringUtils.hasText(groupParam) ? groupParam : (body != null ? body.group() : null);
        List<Map<String, Object>> all = billService.settlements(group, CurrentUser.id());
        // Note: the client reads the misspelled key "allAssigments" — kept intentionally for compatibility.
        return ResponseEntity.ok(ApiResponse.success("Settlement sent to frontend")
                .with("allAssignments", all)
                .with("allAssigments", all));
    }

    @PostMapping("/payment")
    public ResponseEntity<?> payment(@Valid @RequestBody PaymentRequest req) {
        Expense expense = billService.recordPayment(req, CurrentUser.id());
        String payer = req.paidBy() != null ? req.paidBy() : CurrentUser.id();
        return ResponseEntity.ok(ApiResponse.success(
                        "Payment of ₹" + req.amount().toPlainString() + " recorded successfully (paid by user " + payer + ")")
                .with("expense", responseMapper.populateExpense(expense)));
    }

    @GetMapping("/split/{expenseId}")
    public ResponseEntity<?> split(@PathVariable String expenseId) {
        Map<String, Object> result = billService.splitExpense(expenseId, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Split calculated successfully")
                .with("totalAmount", result.get("totalAmount"))
                .with("splitMethod", result.get("splitMethod"))
                .with("perUser", result.get("perUser"))
                .with("settlements", result.get("settlements")));
    }

    @GetMapping("/getAllBills")
    public ResponseEntity<?> getAllBills(@RequestParam(value = "group", required = false) String groupParam,
                                         @RequestBody(required = false) GroupBodyRequest body) {
        String group = StringUtils.hasText(groupParam) ? groupParam : (body != null ? body.group() : null);
        List<Expense> bills = billService.getAllBills(group, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Bills fetched successfully")
                .with("bills", responseMapper.populateExpenses(bills))
                .with("count", bills.size()));
    }

    /** Delete by JSON body { expenseId } — the shape the Flutter client's deleteBill sends. */
    @DeleteMapping("/deleteBill")
    public ResponseEntity<?> deleteBill(@Valid @RequestBody DeleteBillRequest req) {
        billService.deleteBill(req.expenseId(), CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Expense deleted successfully"));
    }

    /** Delete by path id — the alternate shape the client's deleteExpense uses. */
    @DeleteMapping("/delete/{expenseId}")
    public ResponseEntity<?> deleteExpense(@PathVariable String expenseId) {
        billService.deleteBill(expenseId, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Expense deleted successfully"));
    }

    /**
     * Streams a receipt image/PDF back for download. Deliberately not a public static resource
     * mapping — that would let any client read any receipt by guessing a filename. Routing through
     * getBillDetails reuses its group-membership check.
     */
    @GetMapping("/{expenseId}/image")
    public ResponseEntity<Resource> getBillImage(@PathVariable String expenseId) {
        Expense expense = billService.getBillDetails(expenseId, CurrentUser.id());
        if (!StringUtils.hasText(expense.getBillImageUrl())) {
            throw ApiException.notFound("This expense has no receipt image");
        }
        Resource resource = fileStorageService.loadAsResource(expense.getBillImageUrl());
        MediaType contentType = MediaType.parseMediaType(fileStorageService.contentTypeFor(expense.getBillImageUrl()));
        return ResponseEntity.ok().contentType(contentType).body(resource);
    }

    /** Audit trail for an expense — who assigned/paid/deleted what, for dispute resolution. */
    @GetMapping("/{expenseId}/audit")
    public ResponseEntity<?> getAuditTrail(@PathVariable String expenseId) {
        var trail = billService.getAuditTrail(expenseId, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Audit trail fetched successfully")
                .with("audit", trail));
    }
}
