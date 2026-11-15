from analyzer.git_analyzer import GitChangeAnalyzer


repository = GitChangeAnalyzer(
    "C:/AI-Change-Impact-Analyzer"
)

changed_files = repository.get_changed_files()

print("\n========== GIT CHANGES ==========")

if changed_files:

    for file in changed_files:
        print("Changed:", file)

else:

    print("No changes detected.")