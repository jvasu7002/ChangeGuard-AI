import ast
import os
from git import Repo


class ChangeDetector:

    def __init__(self, project_path, repository_path):

        self.project_path = project_path
        self.repository_path = repository_path

        self.repo = Repo(repository_path)

    # ==========================================
    # Get functions from Python source
    # ==========================================

    def get_functions_from_source(self, source):

        functions = {}

        try:

            tree = ast.parse(source)

            for node in ast.walk(tree):

                if isinstance(
                    node,
                    (ast.FunctionDef, ast.AsyncFunctionDef)
                ):

                    # Remove line numbers and locations
                    # so comparison focuses on actual code
                    function_ast = ast.dump(
                        node,
                        include_attributes=False
                    )

                    functions[node.name] = {
                        "line": node.lineno,
                        "ast": function_ast
                    }

        except SyntaxError:
            pass

        return functions

    # ==========================================
    # Read current working version
    # ==========================================

    def get_current_source(self, file_path):

        full_path = os.path.join(
            self.repository_path,
            file_path
        )

        if not os.path.exists(full_path):
            return ""

        try:

            with open(
                full_path,
                "r",
                encoding="utf-8"
            ) as file:

                return file.read()

        except (
            UnicodeDecodeError,
            OSError
        ):

            return ""

    # ==========================================
    # Read Git HEAD version
    # ==========================================

    def get_previous_source(self, file_path):

        try:

            source = self.repo.git.show(
                f"HEAD:{file_path}"
            )

            return source

        except Exception:

            # File may be newly created
            return ""

    # ==========================================
    # Detect exact changed functions
    # ==========================================

    def detect_changed_functions(
        self,
        changed_files
    ):

        changed_functions = []

        for file_path in changed_files:

            # Ignore compiled files
            if file_path.endswith(".pyc"):
                continue

            # Ignore cache
            if "__pycache__" in file_path:
                continue

            # Only Python files
            if not file_path.endswith(".py"):
                continue

            # ----------------------------------
            # Current version
            # ----------------------------------

            current_source = (
                self.get_current_source(
                    file_path
                )
            )

            current_functions = (
                self.get_functions_from_source(
                    current_source
                )
            )

            # ----------------------------------
            # Previous Git version
            # ----------------------------------

            previous_source = (
                self.get_previous_source(
                    file_path
                )
            )

            previous_functions = (
                self.get_functions_from_source(
                    previous_source
                )
            )

            # ----------------------------------
            # Compare functions
            # ----------------------------------

            all_function_names = set(
                current_functions.keys()
            ).union(
                previous_functions.keys()
            )

            for function_name in all_function_names:

                current = current_functions.get(
                    function_name
                )

                previous = previous_functions.get(
                    function_name
                )

                # ------------------------------
                # New function
                # ------------------------------

                if previous is None:

                    changed_functions.append({
                        "file": file_path,
                        "function": function_name,
                        "line": current["line"],
                        "change_type": "ADDED"
                    })

                # ------------------------------
                # Deleted function
                # ------------------------------

                elif current is None:

                    changed_functions.append({
                        "file": file_path,
                        "function": function_name,
                        "line": None,
                        "change_type": "DELETED"
                    })

                # ------------------------------
                # Modified function
                # ------------------------------

                elif current["ast"] != previous["ast"]:

                    changed_functions.append({
                        "file": file_path,
                        "function": function_name,
                        "line": current["line"],
                        "change_type": "MODIFIED"
                    })

        return changed_functions