package com.splitpay.dto;

import jakarta.validation.constraints.NotBlank;

import java.util.List;

public final class GroupDtos {

    private GroupDtos() {
    }

    /** Body for POST /group/create. The original read { name, members }. */
    public record CreateGroupRequest(
            @NotBlank(message = "Group name is required") String name,
            List<@NotBlank(message = "member id cannot be blank") String> members) {
    }
}
