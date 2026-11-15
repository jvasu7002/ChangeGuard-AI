class TestRecommender:

    def __init__(self, impact_result):
        self.impact_result = impact_result

    def recommend_tests(self):

        changed_function = self.impact_result["changed"]
        affected_functions = self.impact_result["affected"]
        impact_level = self.impact_result["impact_level"]

        recommendations = []

        # ==========================================
        # 1. Test the changed function
        # ==========================================

        changed_name = changed_function.split(":")[-1]

        recommendations.append(
            f"Test changed function: {changed_name}()"
        )

        # ==========================================
        # 2. Test directly affected functions
        # ==========================================

        for function in affected_functions:

            function_name = function.split(":")[-1]

            recommendations.append(
                f"Test affected function: {function_name}()"
            )

        # ==========================================
        # 3. Detect application area
        # ==========================================

        all_functions = [
            changed_function
        ] + affected_functions

        function_names = [
            function.split(":")[-1].lower()
            for function in all_functions
        ]

        # Authentication
        if any(
            name in function_names
            for name in [
                "login",
                "authenticate",
                "signin",
                "signup",
                "register"
            ]
        ):

            recommendations.append(
                "Run authentication/login flow tests"
            )

        # User management
        if any(
            "user" in name
            for name in function_names
        ):

            recommendations.append(
                "Run user management tests"
            )

        # Order processing
        if any(
            "order" in name
            for name in function_names
        ):

            recommendations.append(
                "Run order processing tests"
            )

        # ==========================================
        # 4. Risk-based recommendation
        # ==========================================

        if impact_level == "HIGH":

            recommendations.append(
                "Run full regression test suite"
            )

        elif impact_level == "MEDIUM":

            recommendations.append(
                "Run tests for all affected modules"
            )

        elif impact_level == "LOW":

            recommendations.append(
                "Run focused unit tests"
            )

        # ==========================================
        # 5. Remove duplicate recommendations
        # ==========================================

        recommendations = list(
            dict.fromkeys(recommendations)
        )

        return recommendations