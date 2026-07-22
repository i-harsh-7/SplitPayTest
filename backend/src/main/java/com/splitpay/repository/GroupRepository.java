package com.splitpay.repository;

import com.splitpay.model.Group;
import org.springframework.data.mongodb.repository.MongoRepository;
import org.springframework.data.mongodb.repository.Query;

import java.util.List;

public interface GroupRepository extends MongoRepository<Group, String> {

    /**
     * Reproduces the Mongoose query:
     * {@code Group.find({ $or: [ { createdBy: id }, { members: id } ] })}.
     */
    @Query("{ '$or': [ { 'createdBy': ?0 }, { 'members': ?0 } ] }")
    List<Group> findByCreatedByOrMember(String userId);
}
