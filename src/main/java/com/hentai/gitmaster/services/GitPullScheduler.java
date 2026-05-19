package com.hentai.gitmaster.services;

import com.hentai.gitmaster.repositories.GitProjectRepository;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

@Component
public class GitPullScheduler {

    private final GitProjectRepository gitProjectRepository;

    public GitPullScheduler(GitProjectRepository gitProjectRepository) {
        this.gitProjectRepository = gitProjectRepository;
    }

    @Scheduled(fixedDelayString = "PT30M")
    public void pullAllProjects() {
        var projects = gitProjectRepository.findAll();
        System.out.println("\u001B[33m--- Scheduled git pull for " + projects.spliterator().estimateSize() + " projects ---\u001B[0m");

        for (var project : projects) {
            Path projectPath = Paths.get(project.getPath());
            if (Files.exists(projectPath) && Files.isDirectory(projectPath)) {
                runGitPull(projectPath, projectPath.getFileName().toString());
            }
        }
    }

    private void runGitPull(Path projectPath, String projectName) {
        try {
            Process process = new ProcessBuilder("git", "pull")
                    .directory(projectPath.toFile())
                    .redirectErrorStream(true)
                    .start();

            try (BufferedReader reader = new BufferedReader(
                    new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
                String line;
                StringBuilder output = new StringBuilder();
                while ((line = reader.readLine()) != null) {
                    output.append(line).append("\n");
                }
                int exitCode = process.waitFor();
                if (exitCode != 0) {
                    System.out.print("\u001B[31m" + output + "\u001B[0m");
                } else {
                    System.out.print("\u001B[32m" + output + "\u001B[0m");
                }
            }
        } catch (Exception e) {
            System.out.println("\u001B[31mFailed to execute git pull for " + projectName + "\u001B[0m");
        }
    }
}
