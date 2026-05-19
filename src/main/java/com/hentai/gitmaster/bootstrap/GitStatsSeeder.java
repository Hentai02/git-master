package com.hentai.gitmaster.bootstrap;

import com.hentai.gitmaster.entities.GitAuthor;
import com.hentai.gitmaster.entities.GitProject;
import com.hentai.gitmaster.repositories.GitAuthorRepository;
import com.hentai.gitmaster.repositories.GitProjectRepository;
import org.jspecify.annotations.NonNull;
import org.springframework.context.ApplicationListener;
import org.springframework.context.event.ContextRefreshedEvent;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
public class GitStatsSeeder implements ApplicationListener<ContextRefreshedEvent> {

    private static final List<String> DEFAULT_PROJECT_PATHS = List.of(
            "D:\\Codes\\itwinkle\\ahapp",
            "D:\\Codes\\itwinkle\\ahhydp",
            "D:\\Codes\\itwinkle\\fjhydp",
            "D:\\Codes\\itwinkle\\gshydp",
            "D:\\Codes\\itwinkle\\gsstwm",
            "D:\\Codes\\itwinkle\\gxapp",
            "D:\\Codes\\itwinkle\\gxhydp",
            "D:\\Codes\\itwinkle\\hnapp",
            "D:\\Codes\\itwinkle\\hnhydp",
            "D:\\Codes\\itwinkle\\hydas",
            "D:\\Codes\\itwinkle\\hydt",
            "D:\\Codes\\itwinkle\\hymt",
            "D:\\Codes\\itwinkle\\hymtdc",
            "D:\\Codes\\itwinkle\\jlapp",
            "D:\\Codes\\itwinkle\\jlhydp",
            "D:\\Codes\\itwinkle\\jsapp",
            "D:\\Codes\\itwinkle\\jshydp",
            "D:\\Codes\\itwinkle\\jspda",
            "D:\\Codes\\itwinkle\\sdapp-bg",
            "D:\\Codes\\itwinkle\\sdhydp",
            "D:\\Codes\\itwinkle\\shhydp",
            "D:\\Codes\\itwinkle\\slwhydp",
            "D:\\Codes\\itwinkle\\thhyasm",
            "D:\\Codes\\itwinkle\\thhydp",
            "D:\\Codes\\itwinkle\\zjhsasm",
            "D:\\Codes\\itwinkle\\zjhydp",
            "D:\\Codes\\itwinkle\\zjhydp-boot",
            "D:\\Codes\\itwinkle\\zjxc",
            "D:\\Codes\\itwinkle\\zjzqline",
            "C:\\Users\\Hentai\\Documents\\HBuilderProjects\\js-hydra-uni"
    );

    private static final List<String> DEFAULT_AUTHORS = List.of(
            "Hentai02", "dongjiawei", "ZYT", "cjj", "jzt", "zy0324", "li.menggang", "sun.fan"
    );

    private final GitProjectRepository gitProjectRepository;
    private final GitAuthorRepository gitAuthorRepository;

    public GitStatsSeeder(GitProjectRepository gitProjectRepository, GitAuthorRepository gitAuthorRepository) {
        this.gitProjectRepository = gitProjectRepository;
        this.gitAuthorRepository = gitAuthorRepository;
    }

    @Override
    public void onApplicationEvent(@NonNull ContextRefreshedEvent event) {
        seedProjects();
        seedAuthors();
    }

    private void seedProjects() {
        for (String path : DEFAULT_PROJECT_PATHS) {
            if (gitProjectRepository.findByPath(path).isEmpty()) {
                GitProject project = new GitProject().setPath(path);
                gitProjectRepository.save(project);
            }
        }
    }

    private void seedAuthors() {
        for (String name : DEFAULT_AUTHORS) {
            if (gitAuthorRepository.findByName(name).isEmpty()) {
                GitAuthor author = new GitAuthor().setName(name);
                gitAuthorRepository.save(author);
            }
        }
    }
}
