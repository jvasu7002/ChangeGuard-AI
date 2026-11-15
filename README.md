*# ChangeGuard AI*



*\*\*AI-Powered Software Change Impact \& Risk Analyzer\*\**



*ChangeGuard AI is a software analysis tool designed to identify the impact of code changes, analyze dependencies, estimate potential risks, and recommend relevant testing activities.*



*It helps developers understand which functions may be affected when code changes are introduced.*



*## Key Features*



*- \*\*GitHub Repository Analysis:\*\* Analyze public GitHub repositories.*

*- \*\*Change Detection:\*\* Identify added, modified, and deleted Python functions.*

*- \*\*Dependency Analysis:\*\* Build a dependency graph to identify affected functions.*

*- \*\*Impact Analysis:\*\* Estimate the impact of code changes.*

*- \*\*Risk Assessment:\*\* Calculate risk scores and classify risk as LOW, MEDIUM, or HIGH.*

*- \*\*Test Recommendations:\*\* Suggest testing activities based on detected changes and risk.*

*- \*\*Interactive Dashboard:\*\* View analysis results through a Flutter-based interface.*



*## Technology Stack*



*| Component | Technologies |*

*|---|---|*

*| Frontend | Flutter, Dart |*

*| Backend | Python, FastAPI |*

*| Code Analysis | Python AST |*

*| Dependency Graph | NetworkX |*

*| Git Integration | GitPython |*

*| API Communication | REST API |*



*## Project Structure*



*```text*

*AI-Change-Impact-Analyzer/*

*│*

*├── backend/*

*│   ├── analyzer/*

*│   │   ├── parser.py*

*│   │   ├── dependency.py*

*│   │   ├── impact.py*

*│   │   ├── risk.py*

*│   │   ├── change\_detector.py*

*│   │   ├── git\_analyzer.py*

*│   │   ├── github\_analyzer.py*

*│   │   ├── report\_generator.py*

*│   │   └── test\_recommender.py*

*│   │*

*│   ├── api/*

*│   ├── sample\_projects/*

*│   ├── main.py*

*│   ├── requirements.txt*

*│   └── ...*

*│*

*├── frontend/*

*│   ├── lib/*

*│   ├── android/*

*│   ├── pubspec.yaml*

*│   └── ...*

*│*

*└── README.md*

*```*



*## Installation and Setup*



*### 1. Clone the Repository*



*```bash*

*git clone https://github.com/jvasu7002/ChangeGuard-AI.git*

*cd ChangeGuard-AI*

*```*



*### 2. Setup Backend*



*```bash*

*cd backend*



*python -m venv venv*

*```*



*Activate the virtual environment:*



*\*\*Windows PowerShell\*\**

*```powershell*

*.\\venv\\Scripts\\Activate.ps1*

*```*



*Install dependencies:*



*```bash*

*pip install -r requirements.txt*

*```*



*Start the backend:*



*```bash*

*uvicorn main:app --reload*

*```*



*Backend API:*

*`http://127.0.0.1:8000`*



*API documentation:*

*`http://127.0.0.1:8000/docs`*



*### 3. Setup Flutter Frontend*



*Open another terminal:*



*```bash*

*cd frontend*

*flutter pub get*

*flutter run*

*```*



*Ensure the backend is running before analyzing repositories.*



*## API Endpoints*



*| Method | Endpoint | Description |*

*|---|---|---|*

*| GET | `/` | Backend welcome endpoint |*

*| GET | `/health` | Check backend health |*

*| GET | `/analyze` | Analyze the configured local project |*

*| POST | `/analyze-repository` | Analyze a public GitHub repository |*



*## How It Works*



*1. User provides a public GitHub repository URL.*

*2. The backend retrieves the repository for analysis.*

*3. The system detects changes between the latest two commits.*

*4. Python AST parsing identifies changed functions.*

*5. NetworkX builds a dependency graph.*

*6. The impact analyzer identifies potentially affected functions.*

*7. The risk analyzer calculates a risk score.*

*8. The test recommender generates suggested testing activities.*

*9. Results are displayed on the Flutter dashboard.*



*## Risk Classification*



*The system classifies estimated risk into three levels:*



*- \*\*LOW:\*\* Limited potential impact.*

*- \*\*MEDIUM:\*\* Moderate potential impact.*

*- \*\*HIGH:\*\* Significant potential impact requiring additional attention.*



*## Current Scope and Limitations*



*- GitHub analysis currently supports public repositories.*

*- GitHub comparison uses the latest two commits.*

*- Function-level change detection currently focuses on Python code.*

*- Dependency and risk results are static-analysis estimates and should be reviewed by developers.*

*- The application requires the backend API to be running for repository analysis.*



*## Future Enhancements*



*- Pull request-based impact analysis.*

*- Support for additional programming languages.*

*- Improved dependency resolution.*

*- AI-assisted code review and risk explanations.*

*- Automated test execution and coverage analysis.*

*- Cloud deployment and team collaboration.*



*## Author*



*\*\*Vasu Jain\*\**



*GitHub: https://github.com/jvasu7002*



*---*



*\*ChangeGuard AI — Understand the impact before your code changes create unexpected problems.\**



