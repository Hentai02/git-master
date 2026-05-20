package com.hentai.gitmaster.repositories;

import com.hentai.gitmaster.entities.CacheData;
import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface CacheDataRepository extends CrudRepository<CacheData, String> {

}
