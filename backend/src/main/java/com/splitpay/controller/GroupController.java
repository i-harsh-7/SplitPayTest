package com.splitpay.controller;

import com.splitpay.dto.GroupDtos.CreateGroupRequest;
import com.splitpay.model.Group;
import com.splitpay.security.CurrentUser;
import com.splitpay.service.GroupService;
import com.splitpay.service.ResponseMapper;
import com.splitpay.web.ApiResponse;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

/**
 * Group endpoints under /api/v1/group, matching the routes declared in authRoutes.js.
 */
@RestController
@RequestMapping("/api/v1/group")
public class GroupController {

    private final GroupService groupService;
    private final ResponseMapper responseMapper;

    public GroupController(GroupService groupService, ResponseMapper responseMapper) {
        this.groupService = groupService;
        this.responseMapper = responseMapper;
    }

    @PostMapping("/create")
    public ResponseEntity<?> create(@Valid @RequestBody CreateGroupRequest req) {
        Group group = groupService.createGroup(req, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("group created successfully!!")
                .with("group", responseMapper.populateGroup(group)));
    }

    @GetMapping("/get/{id}")
    public ResponseEntity<?> get(@PathVariable String id) {
        Group group = groupService.getGroup(id, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("Group details fetched successfully")
                .with("group", responseMapper.populateGroup(group)));
    }

    @GetMapping("/getAll")
    public ResponseEntity<?> getAll() {
        var groups = groupService.getAllGroups(CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("fetched data successfully")
                .with("groups", responseMapper.populateGroups(groups)));
    }

    @DeleteMapping("/delete/{id}")
    public ResponseEntity<?> delete(@PathVariable String id) {
        groupService.deleteGroup(id, CurrentUser.id());
        return ResponseEntity.ok(ApiResponse.success("succussfully deleted the group"));
    }
}
