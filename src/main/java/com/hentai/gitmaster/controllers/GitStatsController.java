package com.hentai.gitmaster.controllers;

import com.hentai.gitmaster.dtos.GitStatReport;
import com.hentai.gitmaster.services.GitReportService;
import com.hentai.gitmaster.services.GitStatsService;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/git-stats")
public class GitStatsController {

    private final GitStatsService gitStatsService;
    private final GitReportService gitReportService;

    public GitStatsController(GitStatsService gitStatsService, GitReportService gitReportService) {
        this.gitStatsService = gitStatsService;
        this.gitReportService = gitReportService;
    }

    @GetMapping("/daily")
    public ResponseEntity<List<GitStatReport>> getDailyStats(
            @RequestParam(required = false) String since,
            @RequestParam(required = false) String until) {
        List<GitStatReport> reports = gitStatsService.collectDailyStats(since, until);
        return ResponseEntity.ok(reports);
    }

    @GetMapping("/daily/csv")
    public ResponseEntity<String> getDailyStatsCsv(
            @RequestParam(required = false) String since,
            @RequestParam(required = false) String until) {
        List<GitStatReport> reports = gitStatsService.collectDailyStats(since, until);
        String csv = gitReportService.generateCsvContent(reports);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=git_report.csv")
                .contentType(MediaType.parseMediaType("text/csv; charset=UTF-8"))
                .body(csv);
    }
}
