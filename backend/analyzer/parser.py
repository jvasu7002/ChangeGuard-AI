import ast
import os


class PythonCodeAnalyzer:

    def __init__(self, project_path):
        self.project_path = project_path

    def analyze_file(self, file_path):

        with open(file_path, "r", encoding="utf-8") as file:
            source_code = file.read()

        tree = ast.parse(source_code)

        result = {
            "file": os.path.relpath(file_path, self.project_path),
            "imports": [],
            "functions": [],
            "classes": []
        }

        for node in ast.iter_child_nodes(tree):

            # -------------------------
            # Imports
            # -------------------------

            if isinstance(node, ast.Import):

                for alias in node.names:
                    result["imports"].append(alias.name)

            elif isinstance(node, ast.ImportFrom):

                if node.module:
                    result["imports"].append(node.module)

            # -------------------------
            # Functions
            # -------------------------

            elif isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):

                function_data = {
                    "name": node.name,
                    "line": node.lineno,
                    "calls": []
                }

                # Find calls INSIDE this function
                for child in ast.walk(node):

                    if isinstance(child, ast.Call):

                        if isinstance(child.func, ast.Name):
                            function_data["calls"].append(
                                child.func.id
                            )

                        elif isinstance(child.func, ast.Attribute):
                            function_data["calls"].append(
                                child.func.attr
                            )

                result["functions"].append(function_data)

            # -------------------------
            # Classes
            # -------------------------

            elif isinstance(node, ast.ClassDef):

                result["classes"].append({
                    "name": node.name,
                    "line": node.lineno
                })

        return result

    def analyze_project(self):

        project_data = []

        for root, directories, files in os.walk(self.project_path):

            directories[:] = [
                d for d in directories
                if d not in [
                    "venv",
                    ".venv",
                    ".git",
                    "__pycache__"
                ]
            ]

            for filename in files:

                if filename.endswith(".py"):

                    file_path = os.path.join(root, filename)

                    try:
                        result = self.analyze_file(file_path)
                        project_data.append(result)

                    except Exception as e:
                        print(
                            f"Could not analyze {file_path}: {e}"
                        )

        return project_data