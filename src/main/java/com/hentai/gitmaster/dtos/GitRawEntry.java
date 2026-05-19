package com.hentai.gitmaster.dtos;

public record GitRawEntry(String date, String author, String project, int added, int removed, int commits) {}
