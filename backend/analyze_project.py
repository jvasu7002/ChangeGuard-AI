import os

from analyzer.parser import PythonCodeAnalyzer
from analyzer.git_analyzer import GitChangeAnalyzer
from analyzer.change_detector import ChangeDetector
from analyzer.dependency import DependencyGraph
from analyzer.impact import ImpactAnalyzer
from analyzer.risk import RiskAnalyzer
from analyzer.test_recommender import TestRecommender

# ==========================================
# PROJECT PATHS
# ==========================================

BACKEND_PATH = os.path.dirname(
    os.path.abspath(__file__)
)

PROJECT_PATH = os.path.join(
    BACKEND_PATH,
    "sample_projects"
)

PROJECT_ROOT = os.path.dirname(
    BACKEND_PATH
)


# ==========================================
# 1. CODE ANALYSIS
# ==========================================

print("\n========== CODE ANALYSIS ==========")

parser = PythonCodeAnalyzer(
    PROJECT_PATH
)

project_data = parser.analyze_project()


# ==========================================
# 2. BUILD DEPENDENCY GRAPH
# ==========================================

print("\n========== DEPENDENCY GRAPH ==========")

dependency_builder = DependencyGraph(
    project_data
)

graph = dependency_builder.build_graph()

dependency_builder.print_graph()


# ==========================================
# 3. GIT CHANGE DETECTION
# ==========================================

print("\n========== GIT CHANGE DETECTION ==========")

git_analyzer = GitChangeAnalyzer(
    PROJECT_ROOT
)

changed_files = git_analyzer.get_changed_files()

if changed_files:

    for file in changed_files:
        print("Changed:", file)

else:

    print("No changed files detected.")


# ==========================================
# 4. FIND FUNCTIONS IN CHANGED FILES
# ==========================================

print("\n========== CHANGED FUNCTIONS ==========")

change_detector = ChangeDetector(
    PROJECT_PATH,
    PROJECT_ROOT
)

project_changed_files = [
    file
    for file in changed_files
    if "backend/sample_projects/" in file.replace("\\", "/")
]

changed_functions = (
    change_detector.detect_changed_functions(
        project_changed_files
    )
)

if changed_functions:

    for function in changed_functions:

        print(
            f"- {function['file']}:"
            f"{function['function']}"
        )

else:

    print("No changed functions detected.")


# ==========================================
# 5. IMPACT + RISK ANALYSIS
# ==========================================

if changed_functions:

    impact_analyzer = ImpactAnalyzer(
        graph
    )

    for function in changed_functions:

        # Example:
        # backend/sample_projects/user.py
        # → user.py
        file_name = os.path.basename(
            function["file"]
        )

        function_name = function["function"]

        changed_function = (
            f"{file_name}:{function_name}"
        )

        # ----------------------------------
        # IMPACT
        # ----------------------------------

        print("\n========== IMPACT ANALYSIS ==========")

        impact = impact_analyzer.analyze_change(
            changed_function
        )

        print(
            "Changed:",
            impact["changed"]
        )

        print(
            "Affected:",
            impact["affected"]
        )

        print(
            "Impact Level:",
            impact["impact_level"]
        )

        print(
            "Reason:",
            impact["reason"]
        )

        # ----------------------------------
        # RISK
        # ----------------------------------

        print("\n========== RISK ANALYSIS ==========")

        risk_analyzer = RiskAnalyzer(
            impact,
            graph
        )

        risk = risk_analyzer.calculate_risk()

        print(
            "Risk Score:",
            risk["risk_score"]
        )

        print(
            "Risk Level:",
            risk["risk_level"]
        )

        print("Reasons:")

        for reason in risk["reasons"]:

            print("-", reason)

else:

    print(
        "\nNo functions available "
        "for impact analysis."
    )

# ==========================================
# TEST RECOMMENDATIONS
# ==========================================

print("\n========== TEST RECOMMENDATIONS ==========")

test_recommender = TestRecommender(
    impact
)

recommendations = (
    test_recommender.recommend_tests()
)

for recommendation in recommendations:

    print("✓", recommendation)