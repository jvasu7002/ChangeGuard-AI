from analyzer.test_recommender import TestRecommender


impact_result = {
    "changed": "user.py:get_user",
    "affected": [
        "auth.py:login"
    ],
    "impact_level": "MEDIUM"
}


recommender = TestRecommender(
    impact_result
)

tests = recommender.recommend_tests()


print("\n========== TEST RECOMMENDATIONS ==========")

for test in tests:
    print("✓", test)