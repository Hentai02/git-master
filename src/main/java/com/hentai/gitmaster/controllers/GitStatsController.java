package com.hentai.gitmaster.controllers;

import com.hentai.gitmaster.dtos.GitStatReport;
import com.hentai.gitmaster.dtos.SearchGitStatReportDto;
import com.hentai.gitmaster.entities.CacheData;
import com.hentai.gitmaster.repositories.CacheDataRepository;
import com.hentai.gitmaster.services.GitReportService;
import com.hentai.gitmaster.services.GitStatsService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/git-stats")
public class GitStatsController {

    private final GitStatsService gitStatsService;
    private final GitReportService gitReportService;
    private final CacheDataRepository cacheDataRepository;

    private final ObjectMapper objectMapper;

    public GitStatsController(GitStatsService gitStatsService,
                              GitReportService gitReportService,
                              CacheDataRepository cacheDataRepository) {
        this.gitStatsService = gitStatsService;
        this.gitReportService = gitReportService;
        this.cacheDataRepository = cacheDataRepository;
        objectMapper = new ObjectMapper();
    }

    @GetMapping("/daily")
    public ResponseEntity<List<GitStatReport>> getDailyStats(SearchGitStatReportDto searchGitStatReportDto) {
        String cacheKey = searchGitStatReportDto.buildCacheKey("searchReports");
        Optional<CacheData> optionalCacheData = cacheDataRepository.findById(cacheKey);

        // Cache hit
        if (optionalCacheData.isPresent()) {
            String reportAsString = optionalCacheData.get().getValue();

            TypeReference<List<GitStatReport>> mapType = new TypeReference<>() {};
            List<GitStatReport> reports = objectMapper.readValue(reportAsString, mapType);

            return ResponseEntity.ok(reports);
        }

        // Cache miss
        List<GitStatReport> reports = gitStatsService.search(searchGitStatReportDto);
        String reportsAsJsonString = objectMapper.writeValueAsString(reports);
        CacheData cacheData = new CacheData(cacheKey, reportsAsJsonString, 600L);
        cacheDataRepository.save(cacheData);

        return ResponseEntity.ok(reports);
    }

    @GetMapping("/daily/csv")
    public ResponseEntity<String> getDailyStatsCsv(
            @RequestParam(required = false) String since,
            @RequestParam(required = false) String until) {
        List<GitStatReport> reports = (since != null || until != null)
                ? gitStatsService.collectDailyStats(since, until)
                : gitStatsService.collectDailyStats();
        String csv = gitReportService.generateCsvContent(reports);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=git_report.csv")
                .contentType(MediaType.parseMediaType("text/csv; charset=UTF-8"))
                .body(csv);
    }
}
