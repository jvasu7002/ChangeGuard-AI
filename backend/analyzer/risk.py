class RiskAnalyzer:

    def __init__(self, impact_result, dependency_graph):

        self.impact_result = impact_result
        self.graph = dependency_graph

    def calculate_risk(self):

        affected = self.impact_result["affected"]

        changed = self.impact_result["changed"]

        # -----------------------------------
        # Count affected functions
        # -----------------------------------

        affected_count = len(affected)

        # -----------------------------------
        # Count affected files
        # -----------------------------------

        affected_files = set()

        for function in affected:

            file_name = function.split(":")[0]

            affected_files.add(file_name)

        affected_file_count = len(affected_files)

        # -----------------------------------
        # Calculate risk score
        # -----------------------------------

        score = 0

        # Affected functions
        if affected_count == 0:
            score += 0

        elif affected_count <= 2:
            score += 2

        elif affected_count <= 5:
            score += 4

        else:
            score += 6

        # Affected files
        if affected_file_count == 1:
            score += 1

        elif affected_file_count <= 3:
            score += 2

        else:
            score += 4

        # -----------------------------------
        # Risk level
        # -----------------------------------

        if score <= 2:
            risk_level = "LOW"

        elif score <= 5:
            risk_level = "MEDIUM"

        else:
            risk_level = "HIGH"

        # -----------------------------------
        # Generate reasons
        # -----------------------------------

        reasons = []

        reasons.append(
            f"{affected_count} dependent function(s) detected."
        )

        reasons.append(
            f"{affected_file_count} affected file(s) detected."
        )

        return {
            "changed": changed,
            "affected_functions": affected,
            "affected_files": list(affected_files),
            "risk_score": score,
            "risk_level": risk_level,
            "reasons": reasons
        }