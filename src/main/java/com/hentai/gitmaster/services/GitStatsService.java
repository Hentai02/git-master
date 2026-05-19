package com.hentai.gitmaster.services;

import com.hentai.gitmaster.dtos.GitGroupKey;
import com.hentai.gitmaster.dtos.GitRawEntry;
import com.hentai.gitmaster.dtos.GitStatReport;
import com.hentai.gitmaster.repositories.GitAuthorRepository;
import com.hentai.gitmaster.repositories.GitProjectRepository;
import org.springframework.stereotype.Service;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.Executors;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import java.util.stream.StreamSupport;

@Service
public class GitStatsService {

    private final GitProjectRepository gitProjectRepository;
    private final GitAuthorRepository gitAuthorRepository;

    public GitStatsService(GitProjectRepository gitProjectRepository, GitAuthorRepository gitAuthorRepository) {
        this.gitProjectRepository = gitProjectRepository;
        this.gitAuthorRepository = gitAuthorRepository;
    }

    public List<GitStatReport> collectDailyStats() {
        return collectDailyStats(null, null);
    }

    public List<GitStatReport> collectDailyStats(String since, String until) {
        System.out.println("\u001B[33m--- Git Daily Statistics ---\u001B[0m");

        List<String> projectPaths = StreamSupport.stream(gitProjectRepository.findAll().spliterator(), false)
                .map(p -> p.getPath())
                .toList();
        List<String> authors = StreamSupport.stream(gitAuthorRepository.findAll().spliterator(), false)
                .map(a -> a.getName())
                .toList();

        ConcurrentLinkedQueue<GitRawEntry> rawData = new ConcurrentLinkedQueue<>();

        try (var executor = Executors.newVirtualThreadPerTaskExecutor()) {
            for (String pathStr : projectPaths) {
                executor.submit(() -> {
                    Path projectPath = Paths.get(pathStr);
                    if (Files.exists(projectPath) && Files.isDirectory(projectPath)) {
                        String pName = projectPath.getFileName().toString();

                        System.out.println("\u001B[36mAnalyzing: " + pName + "\u001B[0m");
                        for (String author : authors) {
                            analyzeGitLog(projectPath, pName, author, rawData, since, until);
                        }
                    }
                });
            }
        }

        if (rawData.isEmpty()) {
            System.out.println("\u001B[31mNo data found!\u001B[0m");
            return List.of();
        }

        Map<GitGroupKey, List<GitRawEntry>> grouped = rawData.stream()
                .collect(Collectors.groupingBy(e -> new GitGroupKey(e.date(), e.author())));

        return grouped.entrySet().stream()
                .map(entry -> {
                    GitGroupKey key = entry.getKey();
                    List<GitRawEntry> list = entry.getValue();

                    String[] dateParts = key.date().split("-");
                    long totalAdded = list.stream().mapToLong(GitRawEntry::added).sum();
                    long totalRemoved = list.stream().mapToLong(GitRawEntry::removed).sum();
                    long totalCommits = list.stream().mapToLong(GitRawEntry::commits).sum();
                    long fileCount = list.stream().filter(e -> e.commits() == 0).count();

                    return new GitStatReport(
                            dateParts[0], dateParts[1], dateParts[2], key.author(),
                            totalAdded, totalRemoved, (totalAdded - totalRemoved), fileCount, totalCommits
                    );
                })
                .sorted(Comparator.comparing(GitStatReport::year)
                        .thenComparing(GitStatReport::month)
                        .thenComparing(GitStatReport::day).reversed())
                .toList();
    }

    public List<GitRawEntry> collectRawEntries(String projectPath, String author) {
        ConcurrentLinkedQueue<GitRawEntry> rawData = new ConcurrentLinkedQueue<>();
        Path path = Paths.get(projectPath);
        if (Files.exists(path) && Files.isDirectory(path)) {
            String pName = path.getFileName().toString();
            analyzeGitLog(path, pName, author, rawData, null, null);
        }
        return new ArrayList<>(rawData);
    }

    private void analyzeGitLog(Path projectPath, String projectName, String author,
                               ConcurrentLinkedQueue<GitRawEntry> rawData,
                               String since, String until) {
        try {
            List<String> command = new ArrayList<>(List.of("git", "log",
                    "--author=" + author,
                    "--pretty=format:%ad",
                    "--date=short",
                    "--numstat"));

            if (since != null && !since.isBlank()) {
                command.add("--since=" + since);
            }
            if (until != null && !until.isBlank()) {
                command.add("--until=" + until);
            }

            Process process = new ProcessBuilder(command)
                    .directory(projectPath.toFile())
                    .start();

            Pattern datePattern = Pattern.compile("^\\d{4}-\\d{2}-\\d{2}$");
            Pattern statPattern = Pattern.compile("^(\\d+)\\s+(\\d+)\\s+(.+)$");

            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                String currentDate = null;

                while ((line = reader.readLine()) != null) {
                    line = line.trim();
                    if (line.isEmpty()) continue;

                    Matcher dateMatcher = datePattern.matcher(line);
                    if (dateMatcher.matches()) {
                        currentDate = line;
                        rawData.add(new GitRawEntry(currentDate, author, projectName, 0, 0, 1));
                        continue;
                    }

                    Matcher statMatcher = statPattern.matcher(line);
                    if (statMatcher.matches() && currentDate != null) {
                        int added = Integer.parseInt(statMatcher.group(1));
                        int removed = Integer.parseInt(statMatcher.group(2));
                        rawData.add(new GitRawEntry(currentDate, author, projectName, added, removed, 0));
                    }
                }
            }
            process.waitFor();
        } catch (Exception e) {
            // 静默失败
        }
    }
}
