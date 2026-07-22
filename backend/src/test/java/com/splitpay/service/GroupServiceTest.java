package com.splitpay.service;

import com.splitpay.dto.GroupDtos.CreateGroupRequest;
import com.splitpay.model.Group;
import com.splitpay.repository.ExpenseRepository;
import com.splitpay.repository.GroupRepository;
import com.splitpay.repository.InviteRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Collections;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class GroupServiceTest {

    @Mock private GroupRepository groupRepository;
    @Mock private ExpenseRepository expenseRepository;
    @Mock private InviteRepository inviteRepository;

    private GroupService service() {
        return new GroupService(groupRepository, expenseRepository, inviteRepository);
    }

    /**
     * Regression test: BillService/InviteService authorize purely on {@code members.contains}, not
     * createdBy, so a creator who isn't in members gets locked out of their own group's expenses
     * and invites. createGroup must always add the creator to members.
     */
    @Test
    void createGroup_alwaysAddsCreatorToMembers() {
        GroupService service = service();
        when(groupRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        CreateGroupRequest req = new CreateGroupRequest("Roommates", null);
        Group group = service.createGroup(req, "creator-1");

        assertThat(group.getMembers()).containsExactly("creator-1");
    }

    @Test
    void createGroup_dedupesIfCreatorAlsoPassedInMembers() {
        GroupService service = service();
        when(groupRepository.save(any())).thenAnswer(inv -> inv.getArgument(0));

        CreateGroupRequest req = new CreateGroupRequest("Roommates", List.of("creator-1", "member-2"));
        Group group = service.createGroup(req, "creator-1");

        assertThat(group.getMembers()).containsExactly("creator-1", "member-2");
    }

    /** Belonging to zero groups is a valid state, not an error. */
    @Test
    void getAllGroups_returnsEmptyListInsteadOfThrowing() {
        GroupService service = service();
        when(groupRepository.findByCreatedByOrMember("new-user")).thenReturn(Collections.emptyList());

        List<Group> result = service.getAllGroups("new-user");

        assertThat(result).isEmpty();
    }
}
