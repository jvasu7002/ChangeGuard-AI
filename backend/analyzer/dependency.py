import networkx as nx


class DependencyGraph:

    def __init__(self, project_data):
        self.project_data = project_data
        self.graph = nx.DiGraph()

    def build_graph(self):

        # -----------------------------------
        # STEP 1: Create file and function nodes
        # -----------------------------------

        for file_data in self.project_data:

            file_name = file_data["file"]

            # Add file node
            self.graph.add_node(
                file_name,
                type="file"
            )

            # Add function nodes
            for function in file_data["functions"]:

                function_name = function["name"]

                function_id = f"{file_name}:{function_name}"

                self.graph.add_node(
                    function_id,
                    type="function"
                )

                # File contains function
                self.graph.add_edge(
                    file_name,
                    function_id,
                    relation="contains"
                )

        # -----------------------------------
        # STEP 2: Create function call relationships
        # -----------------------------------

        for file_data in self.project_data:

            file_name = file_data["file"]

            for function in file_data["functions"]:

                current_function = function["name"]

                current_function_id = (
                    f"{file_name}:{current_function}"
                )

                # Calls made by this specific function
                for called_function in function["calls"]:

                    target = self.find_function(
                        called_function
                    )

                    if target:

                        self.graph.add_edge(
                            current_function_id,
                            target,
                            relation="calls"
                        )

        return self.graph

    # -----------------------------------
    # Find a function in the project
    # -----------------------------------

    def find_function(self, function_name):

        for file_data in self.project_data:

            file_name = file_data["file"]

            for function in file_data["functions"]:

                if function["name"] == function_name:

                    return f"{file_name}:{function_name}"

        return None

    # -----------------------------------
    # Print dependency graph
    # -----------------------------------

    def print_graph(self):

        print("\n========== DEPENDENCY GRAPH ==========")

        for source, target, data in self.graph.edges(data=True):

            print(
                f"{source} "
                f"--[{data['relation']}]--> "
                f"{target}"
            )