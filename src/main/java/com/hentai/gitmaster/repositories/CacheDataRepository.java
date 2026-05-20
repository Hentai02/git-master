package com.hentai.gitmaster.repositories;

import com.hentai.gitmaster.entities.CacheData;
import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface CacheDataRepository extends CrudRepository<CacheData, String> {

    List<CacheData> findByIdContainingIgnoreCase(String keyword);

}
