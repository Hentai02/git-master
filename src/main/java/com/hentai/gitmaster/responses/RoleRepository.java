package com.hentai.gitmaster.responses;

import com.hentai.gitmaster.entities.Role;
import com.hentai.gitmaster.entities.RoleEnum;
import org.springframework.data.repository.CrudRepository;

import java.util.Optional;

public interface RoleRepository extends CrudRepository<Role, Integer> {
    Optional<Role> findByName(RoleEnum name);
}
