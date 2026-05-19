package com.hentai.gitmaster.services;

import com.hentai.gitmaster.dtos.GitStatReport;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;

@Service
public class GitReportService {

    public String formatTable(List<GitStatReport> reports) {
        StringBuilder sb = new StringBuilder();
        sb.append(String.format("%-12s %-12s %-12s %-15s %-10s %-10s %-10s %-10s\n",
                "Year", "Month", "Day", "Author", "Added", "Removed", "Net", "Files"));
        sb.append("-".repeat(95)).append("\n");
        for (GitStatReport r : reports) {
            sb.append(r).append("\n");
        }
        return sb.toString();
    }

    public void printTable(List<GitStatReport> reports) {
        System.out.println(formatTable(reports));
    }

    public String exportToCsv(List<GitStatReport> reports) {
        String timestamp = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyyMMdd_HHmm"));
        String fileName = "git_report_sofar_" + timestamp + ".csv";

        List<String> lines = new ArrayList<>();
        lines.add("\"Year\",\"Month\",\"Day\",\"Author\",\"Added\",\"Removed\",\"Net\",\"Files\"");

        for (GitStatReport r : reports) {
            lines.add(String.format("\"%s\",\"%s\",\"%s\",\"%s\",\"%d\",\"%d\",\"%d\",\"%d\"",
                    r.year(), r.month(), r.day(), r.author(), r.added(), r.removed(), r.net(), r.files()));
        }

        try {
            Files.write(Paths.get(fileName), lines, StandardCharsets.UTF_8);
            System.out.println("\u001B[32mSuccess! Report saved to " + fileName + "\u001B[0m");
        } catch (IOException e) {
            System.out.println("\u001B[31mFailed to save CSV file: " + e.getMessage() + "\u001B[0m");
        }

        return fileName;
    }

    public String generateCsvContent(List<GitStatReport> reports) {
        StringBuilder sb = new StringBuilder();
        sb.append("\"Year\",\"Month\",\"Day\",\"Author\",\"Added\",\"Removed\",\"Net\",\"Files\"\n");

        for (GitStatReport r : reports) {
            sb.append(String.format("\"%s\",\"%s\",\"%s\",\"%s\",\"%d\",\"%d\",\"%d\",\"%d\"\n",
                    r.year(), r.month(), r.day(), r.author(), r.added(), r.removed(), r.net(), r.files()));
        }

        return sb.toString();
    }
}
