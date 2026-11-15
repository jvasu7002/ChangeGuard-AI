from analyzer.parser import PythonCodeAnalyzer
from analyzer.dependency import DependencyGraph
from analyzer.impact import ImpactAnalyzer
from analyzer.risk import RiskAnalyzer

analyzer = PythonCodeAnalyzer("sample_projects")

result = analyzer.analyze_project()


print("\n========== CODE ANALYSIS ==========")

for file in result:

    print("\n==============================")
    print("FILE:", file["file"])
    print("IMPORTS:", file["imports"])

    print("FUNCTIONS:")

    for function in file["functions"]:

        print(
            f"  {function['name']}"
            f"() → calls: {function['calls']}"
        )

    print("CLASSES:", file["classes"])


dependency_graph = DependencyGraph(result)

graph = dependency_graph.build_graph()

dependency_graph.print_graph()
print("\n========== IMPACT ANALYSIS ==========")

impact_analyzer = ImpactAnalyzer(graph)

changed_function = "user.py:get_user"

impact = impact_analyzer.analyze_change(
    changed_function
)

print("Changed:", impact["changed"])
print("Affected:", impact["affected"])
print("Impact Level:", impact["impact_level"])
print("Reason:", impact["reason"])

print("\n========== RISK ANALYSIS ==========")

risk_analyzer = RiskAnalyzer(
    impact,
    graph
)

risk = risk_analyzer.calculate_risk()

print("Changed:", risk["changed"])
print("Affected Functions:", risk["affected_functions"])
print("Affected Files:", risk["affected_files"])
print("Risk Score:", risk["risk_score"])
print("Risk Level:", risk["risk_level"])

print("Reasons:")

for reason in risk["reasons"]:
    print("-", reason)