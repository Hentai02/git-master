package com.hentai.gitmaster.repositories;

import com.hentai.gitmaster.entities.GitAuthor;
import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface GitAuthorRepository extends CrudRepository<GitAuthor, Integer> {
    Optional<GitAuthor> findByName(String name);
}
