package com.hentai.gitmaster.dtos;

public record GitStatReport(String year, String month, String day, String author,
                            long added, long removed, long net, long files) {
    @Override
    public String toString() {
        return String.format("%-12s %-12s %-12s %-15s %-10d %-10d %-10d %-10d",
                year, month, day, author, added, removed, net, files);
    }
}
