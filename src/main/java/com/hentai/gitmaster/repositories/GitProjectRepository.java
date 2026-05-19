package com.hentai.gitmaster.repositories;

import com.hentai.gitmaster.entities.GitProject;
import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface GitProjectRepository extends CrudRepository<GitProject, Integer> {
    Optional<GitProject> findByPath(String path);
}
