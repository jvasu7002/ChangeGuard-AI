
import ast
import os
import shutil
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from git import Repo

from analyzer.parser import PythonCodeAnalyzer
from analyzer.git_analyzer import GitChangeAnalyzer
from analyzer.change_detector import ChangeDetector
from analyzer.dependency import DependencyGraph
from analyzer.impact import ImpactAnalyzer
from analyzer.risk import RiskAnalyzer
from analyzer.test_recommender import TestRecommender
from analyzer.report_generator import ReportGenerator
from analyzer.github_analyzer import clone_public_repository


app = FastAPI(
    title="AI Software Change Impact Analyzer",
    description="Analyze software changes, dependencies, and risks.",
    version="1.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=False,
    allow_methods=["GET", "POST"],
    allow_headers=["*"],
)

BACKEND_PATH = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.dirname(BACKEND_PATH)
PROJECT_PATH = os.path.join(BACKEND_PATH, "sample_projects")


class RepositoryRequest(BaseModel):
    repository_url: str


@app.get("/")
def home():
    return {
        "message": "AI Software Change Impact Analyzer API",
        "status": "running",
    }


@app.get("/health")
def health():
    return {"status": "healthy"}


# =========================================================
# EXISTING LOCAL PROJECT ANALYSIS
# =========================================================

@app.get("/analyze")
def analyze_project():
    parser = PythonCodeAnalyzer(PROJECT_PATH)
    project_data = parser.analyze_project()

    dependency_builder = DependencyGraph(project_data)
    graph = dependency_builder.build_graph()

    git_analyzer = GitChangeAnalyzer(PROJECT_ROOT)
    changed_files = git_analyzer.get_changed_files()

    project_changed_files = []

    for file in changed_files:
        normalized = file.replace("\\", "/")

        if (
            "backend/sample_projects/" in normalized
            and normalized.endswith(".py")
            and "__pycache__" not in normalized
        ):
            project_changed_files.append(file)

    change_detector = ChangeDetector(
        PROJECT_PATH,
        PROJECT_ROOT,
    )

    changed_functions = change_detector.detect_changed_functions(
        project_changed_files
    )

    results = []

    for function in changed_functions:
        file_name = os.path.basename(function["file"])
        function_name = function["function"]
        changed_function = f"{file_name}:{function_name}"

        impact = ImpactAnalyzer(graph).analyze_change(
            changed_function
        )

        risk = RiskAnalyzer(impact, graph).calculate_risk()

        recommendations = TestRecommender(
            impact
        ).recommend_tests()

        report = ReportGenerator(
            impact,
            risk,
            recommendations,
        ).generate_report()

        results.append({
            "changed_function": changed_function,
            "change_type": function.get(
                "change_type", "MODIFIED"
            ),
            "affected_functions": impact["affected"],
            "impact_level": impact["impact_level"],
            "impact_reason": impact["reason"],
            "risk_score": risk["risk_score"],
            "risk_level": risk["risk_level"],
            "risk_reasons": risk["reasons"],
            "summary": report["summary"],
            "recommended_action": report["recommended_action"],
            "recommended_tests": report["recommended_tests"],
        })

    return {
        "status": "success",
        "changed_files": project_changed_files,
        "changed_functions": changed_functions,
        "results": results,
    }


# =========================================================
# GITHUB REPOSITORY ANALYSIS HELPERS
# =========================================================

def get_python_functions(source):
    """Extract Python function definitions and AST representations."""

    functions = {}

    try:
        tree = ast.parse(source)

        for node in ast.walk(tree):
            if isinstance(
                node,
                (ast.FunctionDef, ast.AsyncFunctionDef),
            ):
                functions[node.name] = {
                    "line": node.lineno,
                    "ast": ast.dump(
                        node,
                        include_attributes=False,
                    ),
                }

    except SyntaxError:
        pass

    return functions


def get_commit_source(repo, commit, file_path):
    """Read a file from a specific Git commit."""

    try:
        return repo.git.show(f"{commit}:{file_path}")
    except Exception:
        return ""


def get_changed_python_files(repo, latest_commit, previous_commit):
    """Get Python files changed between two commits."""

    if previous_commit:
        diff = previous_commit.diff(latest_commit)

        paths = set()

        for item in diff:
            if item.a_path:
                paths.add(item.a_path)

            if item.b_path:
                paths.add(item.b_path)

    else:
        # For a repository with only one commit, analyze its
        # Python files as initial additions.
        paths = {
            item.path
            for item in latest_commit.tree.traverse()
            if item.type == "blob" and item.path.endswith(".py")
        }

    return sorted({
        path
        for path in paths
        if path.endswith(".py")
        and "__pycache__" not in path
        and not any(
            part in {"venv", ".venv", "node_modules"}
            for part in Path(path).parts
        )
    })


# =========================================================
# PUBLIC GITHUB REPOSITORY ANALYSIS
# =========================================================

@app.post("/analyze-repository")
def analyze_repository(request: RepositoryRequest):
    temporary_directory = None

    try:
        # Clone a public repository into a temporary directory.
        temporary_directory, repository_path = (
            clone_public_repository(request.repository_url)
        )

        repo = Repo(repository_path)

        commits = list(repo.iter_commits(max_count=2))

        if not commits:
            raise HTTPException(
                status_code=400,
                detail="The repository has no commits to analyze.",
            )

        latest_commit = commits[0]
        previous_commit = (
            commits[1] if len(commits) > 1 else None
        )

        changed_paths = get_changed_python_files(
            repo,
            latest_commit,
            previous_commit,
        )

        # Build dependency graph from the current repository.
        parser = PythonCodeAnalyzer(repository_path)
        project_data = parser.analyze_project()

        dependency_builder = DependencyGraph(project_data)
        graph = dependency_builder.build_graph()

        results = []
        changed_functions = []

        for file_path in changed_paths:
            current_source = get_commit_source(
                repo,
                latest_commit.hexsha,
                file_path,
            )

            previous_source = (
                get_commit_source(
                    repo,
                    previous_commit.hexsha,
                    file_path,
                )
                if previous_commit
                else ""
            )

            current_functions = get_python_functions(
                current_source
            )

            previous_functions = get_python_functions(
                previous_source
            )

            all_function_names = (
                set(current_functions)
                | set(previous_functions)
            )

            for function_name in sorted(all_function_names):
                current = current_functions.get(function_name)
                previous = previous_functions.get(function_name)

                # Skip functions whose AST did not change.
                if (
                    current is not None
                    and previous is not None
                    and current["ast"] == previous["ast"]
                ):
                    continue

                if current is None:
                    change_type = "DELETED"
                    line_number = None
                elif previous is None:
                    change_type = "ADDED"
                    line_number = current["line"]
                else:
                    change_type = "MODIFIED"
                    line_number = current["line"]

                changed_item = {
                    "file": file_path,
                    "function": function_name,
                    "line": line_number,
                    "change_type": change_type,
                }

                changed_functions.append(changed_item)

                changed_function = (
                    f"{file_path}:{function_name}"
                )

                impact = ImpactAnalyzer(graph).analyze_change(
                    changed_function
                )

                risk = RiskAnalyzer(
                    impact,
                    graph,
                ).calculate_risk()

                recommendations = TestRecommender(
                    impact
                ).recommend_tests()

                report = ReportGenerator(
                    impact,
                    risk,
                    recommendations,
                ).generate_report()

                results.append({
                    "changed_function": changed_function,
                    "change_type": change_type,
                    "affected_functions": impact["affected"],
                    "impact_level": impact["impact_level"],
                    "impact_reason": impact["reason"],
                    "risk_score": risk["risk_score"],
                    "risk_level": risk["risk_level"],
                    "risk_reasons": risk["reasons"],
                    "summary": report["summary"],
                    "recommended_action": (
                        report["recommended_action"]
                    ),
                    "recommended_tests": (
                        report["recommended_tests"]
                    ),
                })

        return {
            "status": "success",
            "repository_url": request.repository_url,
            "latest_commit": latest_commit.hexsha,
            "baseline_commit": (
                previous_commit.hexsha
                if previous_commit
                else None
            ),
            "changed_files": changed_paths,
            "changed_functions": changed_functions,
            "results": results,
        }

    except HTTPException:
        raise

    except ValueError as exc:
        raise HTTPException(
            status_code=400,
            detail=str(exc),
        ) from exc

    except Exception as exc:
        # Avoid exposing internal exception details to API clients.
        print(f"Repository analysis failed: {type(exc).__name__}: {exc}")

        raise HTTPException(
            status_code=500,
            detail=(
                "Repository analysis failed. "
                "Check the backend terminal for details."
            ),
        ) from exc

    finally:
        # Always remove the temporary clone after analysis.
        if temporary_directory:
            shutil.rmtree(
                temporary_directory,
                ignore_errors=True,
            )
