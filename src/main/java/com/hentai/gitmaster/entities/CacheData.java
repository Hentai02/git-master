package com.hentai.gitmaster.entities;

import lombok.AllArgsConstructor;
import lombok.Getter;
import lombok.experimental.Accessors;
import org.springframework.data.annotation.Id;
import org.springframework.data.redis.core.RedisHash;
import org.springframework.data.redis.core.TimeToLive;
import org.springframework.data.redis.core.index.Indexed;

@AllArgsConstructor
@Getter
@Accessors(chain = true)
//@RedisHash("cacheData")
@RedisHash(value = "cacheData", timeToLive = 10)
public class CacheData {
    @Id
    private String key;

    @Indexed
    private String value;

    @TimeToLive
    private Long ttl;
}
