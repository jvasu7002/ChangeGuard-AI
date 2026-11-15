import networkx as nx


class ImpactAnalyzer:

    def __init__(self, dependency_graph):
        self.graph = dependency_graph

    def analyze_change(self, changed_function):

        # Check whether the changed function exists
        if changed_function not in self.graph:

            return {
                "changed": changed_function,
                "affected": [],
                "impact_level": "UNKNOWN",
                "reason": "Function not found in dependency graph."
            }

        # Find all direct and indirect dependencies
        affected_nodes = nx.ancestors(
            self.graph,
            changed_function
        )

        # Keep only function nodes
        affected_functions = [
            node
            for node in affected_nodes
            if self.graph.nodes[node].get("type") == "function"
        ]

        # Sort for consistent output
        affected_functions = sorted(
            affected_functions
        )

        # Calculate impact level
        if len(affected_functions) == 0:

            impact_level = "LOW"

        elif len(affected_functions) <= 2:

            impact_level = "MEDIUM"

        else:

            impact_level = "HIGH"

        return {
            "changed": changed_function,
            "affected": affected_functions,
            "impact_level": impact_level,
            "reason": self.generate_reason(
                affected_functions,
                impact_level
            )
        }

    def generate_reason(
        self,
        affected_functions,
        impact_level
    ):

        if not affected_functions:

            return (
                "No dependent functions were found."
            )

        return (
            f"The changed function has "
            f"{len(affected_functions)} dependent "
            f"function(s), including direct and "
            f"indirect dependencies. "
            f"This results in {impact_level} "
            f"potential impact."
        )