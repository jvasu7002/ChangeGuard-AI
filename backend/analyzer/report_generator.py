
class ReportGenerator:
    def __init__(self, impact, risk, recommendations):
        self.impact = impact
        self.risk = risk
        self.recommendations = recommendations

    def generate_report(self):
        changed_function = self.impact["changed"]
        affected_functions = self.impact["affected"]
        risk_level = self.risk["risk_level"]

        summary = (
            f"{changed_function} was changed. "
            f"{len(affected_functions)} dependent function(s) "
            "were identified."
        )

        if risk_level == "HIGH":
            action = (
                "Review affected components and run regression "
                "tests before merging."
            )
        elif risk_level == "MEDIUM":
            action = (
                "Review affected functions and run their relevant "
                "tests before merging."
            )
        else:
            action = (
                "Run focused unit tests for the changed function."
            )

        return {
            "summary": summary,
            "recommended_action": action,
            "risk_level": risk_level,
            "affected_functions": affected_functions,
            "recommended_tests": self.recommendations
        }
