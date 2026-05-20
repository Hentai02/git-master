package com.hentai.gitmaster.dtos;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import lombok.experimental.Accessors;

@NoArgsConstructor
@AllArgsConstructor
@Data
@Accessors(chain = true)
public class SearchGitStatReportDto {
    private String since;
    private String until;

    public String buildCacheKey(String keyPrefix) {
        StringBuilder builder = new StringBuilder(keyPrefix);

        if (since != null) {
            builder.append(":since=").append(since);
        }

        if (until != null) {
            builder.append(":until=").append(until);
        }

        return builder.toString();
    }
}
