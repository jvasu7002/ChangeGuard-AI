from git import Repo


class GitChangeAnalyzer:

    def __init__(self, repository_path):
        self.repository_path = repository_path
        self.repo = Repo(repository_path)

    def get_changed_files(self):

        changed_files = []

        # Modified / deleted / added files
        for item in self.repo.index.diff(None):

            file_path = item.a_path

            if self.is_valid_source_file(file_path):
                changed_files.append(file_path)

        # Untracked files
        for file_path in self.repo.untracked_files:

            if self.is_valid_source_file(file_path):
                changed_files.append(file_path)

        return list(set(changed_files))

    def is_valid_source_file(self, file_path):

        # Ignore compiled Python files
        if file_path.endswith(".pyc"):
            return False

        # Ignore Python cache directories
        if "__pycache__" in file_path:
            return False

        return True