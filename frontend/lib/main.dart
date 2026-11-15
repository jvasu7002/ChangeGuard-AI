import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const apiUrl = 'http://127.0.0.1:8000/analyze';
const repositoryApiUrl = 'http://127.0.0.1:8000/analyze-repository';
const healthApiUrl = 'http://127.0.0.1:8000/health';
const bg = Color(0xFF10152D);
const cyan = Color(0xFF64E7F5);
const violet = Color(0xFFB59BFF);
const muted = Color(0xFF9EA8CA);
const pink = Color(0xFFFF8FC7);

void main() => runApp(const ChangeGuardApp());

class ChangeGuardApp extends StatelessWidget {
  const ChangeGuardApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ChangeGuard AI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: bg,
          colorScheme: ColorScheme.fromSeed(seedColor: violet, brightness: Brightness.dark),
        ),
        home: const DashboardPage(),
      );
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool loading = false;
  bool repositoryLoading = false;
  bool backendConnected = false;
  bool checkingConnection = false;
  final TextEditingController repositoryController = TextEditingController();
  String? error;
  Map<String, dynamic> payload = {};
  List<dynamic> results = [], files = [], functions = [];
  int selectedNav = 0;

  @override
  void initState() {
    super.initState();
    loadAnalysis();
  }

  @override
  void dispose() {
    repositoryController.dispose();
    super.dispose();
  }

  void applyAnalysisResponse(Map<String, dynamic> decoded) {
    payload = decoded;
    results = decoded['results'] is List
        ? List<dynamic>.from(decoded['results'])
        : [];
    files = decoded['changed_files'] is List
        ? List<dynamic>.from(decoded['changed_files'])
        : [];
    functions = decoded['changed_functions'] is List
        ? List<dynamic>.from(decoded['changed_functions'])
        : [];
  }

  Future<void> analyzeRepository() async {
    final repositoryUrl = repositoryController.text.trim();

    if (repositoryUrl.isEmpty) {
      setState(() => error = 'Please enter a public GitHub repository URL.');
      return;
    }

    if (!repositoryUrl.startsWith('https://github.com/')) {
      setState(() => error = 'Use a public GitHub URL, for example https://github.com/owner/repository');
      return;
    }

    if (repositoryLoading || loading) return;

    setState(() {
      repositoryLoading = true;
      error = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(repositoryApiUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'repository_url': repositoryUrl}),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'API returned HTTP ${response.statusCode}';
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['detail'] != null) {
            message = body['detail'].toString();
          }
        } catch (_) {}
        throw Exception(message);
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected API response format');
      }

      if (!mounted) return;
      setState(() {
        applyAnalysisResponse(decoded);
        backendConnected = true;
        selectedNav = 0;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          backendConnected = false;
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => repositoryLoading = false);
      }
    }
  }

  Future<void> checkConnection() async {
    if (checkingConnection) return;
    setState(() => checkingConnection = true);

    String message;
    try {
      final response = await http
          .get(Uri.parse(healthApiUrl))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        setState(() => backendConnected = true);
        message = 'Backend connection successful.';
      } else {
        if (!mounted) return;
        setState(() => backendConnected = false);
        message = 'Backend responded with HTTP ${response.statusCode}.';
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => backendConnected = false);
      message = 'Could not connect. Make sure the FastAPI backend is running.';
    } finally {
      if (mounted) setState(() => checkingConnection = false);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: backendConnected ? const Color(0xFF176B59) : const Color(0xFF8A3948),
      ));
  }

  void showAboutChangeGuard() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF202744),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(Icons.hub_rounded, color: cyan, size: 34),
        title: const Text('About ChangeGuard AI'),
        content: const SingleChildScrollView(
          child: Text(
            'ChangeGuard AI is a software change impact and risk analysis tool. '
            'It examines Python code changes, traces function dependencies, '
            'identifies potentially affected functions, estimates change risk, '
            'and recommends tests to help developers review changes before integration.\n\n'
            'The current prototype supports public GitHub repositories and uses '
            'Python AST analysis with Git commit comparison. Its findings are '
            'static-analysis estimates and should be reviewed alongside real tests.',
            style: TextStyle(color: Color(0xFFD6DCF2), height: 1.55, fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> loadAnalysis() async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    try {
      final response = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode>= 300) {
        throw Exception('API returned HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException('Unexpected API response format');
      if (!mounted) return;
      setState(() {
        applyAnalysisResponse(decoded);
        backendConnected = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          backendConnected = false;
          error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  int countRisk(String term) => results.where((r) {
    final m = asMap(r);
    return str(m['risk_level'] ?? m['impact_level']).toUpperCase().contains(term);
  }).length;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 850;
    return Scaffold(
      bottomNavigationBar: compact ? compactNavigationBar() : null,
      body: Stack(children: [
        const Positioned.fill(child: GlowBackground()),
        SafeArea(child: Row(children: [
          if (!compact) sideRail(),
          Expanded(child: Column(children: [
            topBar(compact),
            Expanded(child: RefreshIndicator(
              onRefresh: loadAnalysis,
              color: cyan,
              child: pageContent(compact),
            )),
          ])),
        ])),
      ]),
    );
  }

  Widget sideRail() => Container(
    width: 214,
    margin: const EdgeInsets.fromLTRB(15, 15, 0, 15),
    child: Glass(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      radius: 25,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 43, height: 43,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [cyan, violet]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.hub_rounded, color: bg, size: 25),
            ),
            const SizedBox(width: 10),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('CHANGEGUARD', style: TextStyle(
                  color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w900, letterSpacing: .7,
                )),
                SizedBox(height: 3),
                Text('Developer workspace', style: TextStyle(color: muted, fontSize: 9)),
              ],
            )),
          ]),
          const SizedBox(height: 27),
          const Padding(
            padding: EdgeInsets.only(left: 10, bottom: 9),
            child: Text('WORKSPACE', style: TextStyle(
              color: muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2,
            )),
          ),
          navItem(Icons.dashboard_rounded, 0, 'Dashboard', 'Overview and analysis'),
          const SizedBox(height: 7),
          navItem(Icons.account_tree_rounded, 1, 'Dependencies', 'Impact relationships'),
          const SizedBox(height: 7),
          navItem(Icons.folder_open_rounded, 2, 'Changed files', 'Files in latest analysis'),
          const Spacer(),
          const Divider(color: Colors.white12),
          const Padding(
            padding: EdgeInsets.only(left: 10, top: 9, bottom: 9),
            child: Text('PREFERENCES', style: TextStyle(
              color: muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.2,
            )),
          ),
          navItem(Icons.settings_outlined, 3, 'Settings', 'API and app information'),
        ],
      ),
    ),
  );

  Widget navItem(IconData icon, int index, String title, String subtitle) {
    final selected = selectedNav == index;
    return Tooltip(
      message: '$title — $subtitle',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => selectedNav = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? violet.withOpacity(.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? violet.withOpacity(.45) : Colors.white.withOpacity(.045),
            ),
          ),
          child: Row(children: [
            Icon(icon, color: selected ? cyan : muted, size: 19),
            const SizedBox(width: 11),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFFD4DAEF),
                  fontSize: 11, fontWeight: FontWeight.w800,
                )),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: muted, fontSize: 9)),
              ],
            )),
            if (selected) const Icon(Icons.chevron_right_rounded, color: cyan, size: 17),
          ]),
        ),
      ),
    );
  }

  Widget compactNavigationBar() => NavigationBar(
    selectedIndex: selectedNav,
    onDestinationSelected: (index) => setState(() => selectedNav = index),
    backgroundColor: const Color(0xFF171D38),
    indicatorColor: violet.withOpacity(.20),
    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    destinations: const [
      NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.account_tree_outlined), selectedIcon: Icon(Icons.account_tree_rounded), label: 'Impact'),
      NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder_rounded), label: 'Files'),
      NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
    ],
  );

  Widget pageContent(bool compact) {
    switch (selectedNav) {
      case 1:
        return dependenciesPage(compact);
      case 2:
        return changedFilesPage(compact);
      case 3:
        return settingsPage(compact);
      default:
        return dashboardPage(compact);
    }
  }

  Widget dashboardPage(bool compact) => ListView(
    padding: EdgeInsets.fromLTRB(compact ? 15 : 30, 20, compact ? 15 : 30, 32),
    children: [
      hero(compact),
      const SizedBox(height: 16),
      repositoryInputCard(compact),
      const SizedBox(height: 20),
      stats(compact),
      const SizedBox(height: 26),
      sectionHeader('Change intelligence', 'Impact, risk and recommended next steps',
        trailing: loading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: cyan))
          : smallButton(Icons.refresh_rounded, 'Run analysis', loadAnalysis)),
      const SizedBox(height: 14),
      if (error != null) errorCard(),
      if (error == null && results.isEmpty && !loading) emptyCard(),
      ...results.asMap().entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: resultCard(asMap(e.value), e.key + 1, compact),
      )),
      const SizedBox(height: 12),
      sectionHeader('Detected files', '${files.length} file(s) returned by the API'),
      const SizedBox(height: 13),
      filesCard(),
      const SizedBox(height: 24),
      const Text('LOCAL ANALYSIS WORKSPACE  ·  POWERED BY YOUR FASTAPI BACKEND',
        style: TextStyle(color: muted, fontSize: 10, letterSpacing: .7)),
    ],
  );

  Widget dependenciesPage(bool compact) {
    final relationships = <Map<String, String>>[];
    for (final raw in results) {
      final item = asMap(raw);
      final changed = str(item['changed_function']);
      for (final affected in listOf(item['affected_functions'])) {
        relationships.add({
          'source': changed,
          'target': str(affected),
          'impact': str(item['impact_level']),
        });
      }
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(compact ? 15 : 30, 22, compact ? 15 : 30, 32),
      children: [
        sectionHeader('Dependency explorer', 'See which functions may be affected by a code change'),
        const SizedBox(height: 18),
        infoPanel(
          icon: Icons.account_tree_rounded,
          title: 'How dependency impact works',
          description: 'ChangeGuard follows function-call relationships in the analyzed Python project and lists dependent functions that may need retesting.',
          accent: violet,
        ),
        const SizedBox(height: 16),
        if (relationships.isEmpty)
          emptyInfoPanel(
            'No dependency relationships available',
            'Run a GitHub repository analysis from the Dashboard. Relationships will appear here when changed functions have detected dependants.',
            Icons.hub_outlined,
          )
        else ...[
          Text('${relationships.length} relationship(s) found',
            style: const TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 12),
          ...relationships.map(dependencyCard),
        ],
        const SizedBox(height: 16),
        infoPanel(
          icon: Icons.info_outline_rounded,
          title: 'Interpretation',
          description: 'These are static-analysis findings, not proof that every listed function will fail. Review the affected code and run the recommended tests.',
          accent: const Color(0xFFFFCE85),
        ),
      ],
    );
  }

  Widget dependencyCard(Map<String, String> relation) => Padding(
    padding: const EdgeInsets.only(bottom: 11),
    child: Glass(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CHANGED FUNCTION', style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .8)),
            const SizedBox(height: 5),
            Text(relation['source'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 9),
              child: Row(children: [
                Icon(Icons.south_rounded, color: cyan, size: 17),
                SizedBox(width: 6),
                Text('may affect', style: TextStyle(color: muted, fontSize: 10)),
              ]),
            ),
            const Text('AFFECTED FUNCTION', style: TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .8)),
            const SizedBox(height: 5),
            Text(relation['target'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ],
        )),
        const SizedBox(width: 10),
        riskBadge(relation['impact'] ?? 'UNKNOWN'),
      ]),
    ),
  );

  Widget changedFilesPage(bool compact) => ListView(
    padding: EdgeInsets.fromLTRB(compact ? 15 : 30, 22, compact ? 15 : 30, 32),
    children: [
      sectionHeader('Changed files', '${files.length} file(s) identified in the latest analysis',
        trailing: smallButton(Icons.refresh_rounded, 'Refresh', loadAnalysis)),
      const SizedBox(height: 16),
      infoPanel(
        icon: Icons.folder_copy_outlined,
        title: 'Repository file changes',
        description: 'This view lists files returned by the current analysis. Select a repository from the Dashboard to run a new GitHub analysis.',
        accent: cyan,
      ),
      const SizedBox(height: 15),
      filesCard(),
      const SizedBox(height: 15),
      if (functions.isNotEmpty)
        infoPanel(
          icon: Icons.functions_rounded,
          title: 'Function changes detected',
          description: functions.map((f) {
            final m = asMap(f);
            return '${str(m['change_type'])}: ${str(m['file'])}:${str(m['function'])}';
          }).join('\n'),
          accent: violet,
        ),
    ],
  );

  Widget settingsPage(bool compact) => ListView(
    padding: EdgeInsets.fromLTRB(compact ? 15 : 30, 22, compact ? 15 : 30, 32),
    children: [
      sectionHeader('Settings', 'Workspace status and project information'),
      const SizedBox(height: 18),
      infoPanel(
        icon: Icons.tune_rounded,
        title: 'Workspace preferences',
        description: 'Manage and review the current ChangeGuard AI workspace.',
        accent: violet,
      ),
      const SizedBox(height: 16),
      settingTile(
        icon: Icons.cloud_done_outlined,
        title: 'Backend connection',
        value: backendConnected ? 'Connected' : 'Not connected',
        detail: backendConnected
            ? 'ChangeGuard AI can communicate with its analysis service.'
            : 'Start the backend service and run an analysis to check the connection.',
        accent: backendConnected ? cyan : const Color(0xFFFFCE85),
      ),
      settingTile(
        icon: Icons.source_outlined,
        title: 'Repository integration',
        value: 'GitHub analysis enabled',
        detail: 'Analyze public GitHub repositories and inspect recent code changes.',
        accent: violet,
      ),
      settingTile(
        icon: Icons.analytics_outlined,
        title: 'Analysis engine',
        value: 'Python AST and dependency analysis',
        detail: 'Detect function changes, trace dependencies, estimate risk and recommend tests.',
        accent: cyan,
      ),
      const SizedBox(height: 10),
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: showAboutChangeGuard,
          child: infoPanel(
            icon: Icons.info_outline_rounded,
            title: 'About ChangeGuard AI',
            description: 'Learn what ChangeGuard AI does, how its analysis works, and what the current prototype supports. Tap to view details.',
            accent: violet,
          ),
        ),
      ),
      const SizedBox(height: 14),
      smallButton(
        checkingConnection ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
        checkingConnection ? 'Checking connection...' : 'Check connection',
        checkConnection,
      ),
    ],
  );

  Widget infoPanel({
    required IconData icon,
    required String title,
    required String description,
    required Color accent,
  }) => Glass(
    radius: 20,
    padding: const EdgeInsets.all(17),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: accent, size: 21),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text(description, style: const TextStyle(color: muted, fontSize: 11, height: 1.55)),
          ],
        )),
      ],
    ),
  );

  Widget emptyInfoPanel(String title, String description, IconData icon) => Glass(
    radius: 20,
    padding: const EdgeInsets.all(20),
    child: Column(children: [
      Icon(icon, color: muted, size: 30),
      const SizedBox(height: 10),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
      const SizedBox(height: 6),
      Text(description, textAlign: TextAlign.center,
        style: const TextStyle(color: muted, fontSize: 11, height: 1.5)),
    ]),
  );

  Widget settingTile({
    required IconData icon,
    required String title,
    required String value,
    required String detail,
    required Color accent,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Glass(
      radius: 17,
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              SelectableText(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(detail, style: const TextStyle(color: muted, fontSize: 10, height: 1.4)),
            ],
          )),
        ],
      ),
    ),
  );

  Widget riskBadge(String level) {
    final color = riskColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Text(level.toUpperCase(), style: TextStyle(
        color: color, fontSize: 9, fontWeight: FontWeight.w900,
      )),
    );
  }

  Widget topBar(bool compact) => Padding(
    padding: EdgeInsets.fromLTRB(compact ? 15 : 30, 16, compact ? 15 : 30, 0),
    child: Row(children: [
      if (compact) ...[
        Container(width: 40, height: 40, decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [cyan, violet]), borderRadius: BorderRadius.circular(13)),
          child: const Icon(Icons.hub_rounded, color: bg)),
        const SizedBox(width: 10),
      ],
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(compact ? 'ChangeGuard AI' : 'CHANGEGUARD  /WORKSPACE',
          style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        if (!compact) const Padding(padding: EdgeInsets.only(top: 5),
          child: Text('Software change intelligence', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
      ])),
      Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: backendConnected ? const Color(0xFF142D35) : const Color(0xFF302A25),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: (backendConnected ? cyan : const Color(0xFFFFCE85)).withOpacity(.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 8, color: backendConnected ? cyan : const Color(0xFFFFCE85)),
          const SizedBox(width: 7),
          Text(
            backendConnected ? 'BACKEND CONNECTED' : 'BACKEND OFFLINE',
            style: TextStyle(
              color: backendConnected ? cyan : const Color(0xFFFFCE85),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .7,
            ),
          ),
        ])),
    ]),
  );

  Widget hero(bool compact) => Glass(radius: 29, padding: EdgeInsets.all(compact ? 22 : 30),
    child: Stack(children: [
      Positioned(right: -18, top: -40, child: Container(width: 200, height: 200,
        decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [violet.withOpacity(.28), Colors.transparent])))),
      Positioned(right: 10, bottom: -30, child: Icon(Icons.account_tree_rounded,
        size: compact ? 90 : 145, color: cyan.withOpacity(.07))),
      Column(crossAxisAlignment: CrossAxisAlignment.start,children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(color: violet.withOpacity(.13), borderRadius: BorderRadius.circular(30),
            border: Border.all(color: violet.withOpacity(.35))),
          child: const Row(mainAxisSize: MainAxisSize.min,children: [
            Icon(Icons.auto_awesome, size: 14, color: violet), SizedBox(width: 7),
            Text('AI-POWERED CODE REVIEW', style: TextStyle(color: violet, fontSize: 10, fontWeight: FontWeight.w800,letterSpacing: 1)),
          ])),
        const SizedBox(height: 18),
        Text('Understand the ripple effect of every change.',
          style: TextStyle(fontSize: compact ? 29 : 40, height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -1.2)),
        const SizedBox(height: 12),
        const Text('Trace dependencies, surface potential risks, and know what to test before you ship.',
          style: TextStyle(color: muted, fontSize: 14, height: 1.6)),
        const SizedBox(height: 22),
        Wrap(spacing: 10, runSpacing: 10, children: [
          gradientButton(Icons.bolt_rounded, loading ? 'Analyzing...' : 'Analyze project', loading ? null : loadAnalysis),
          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.04), borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.code_rounded, size: 16, color: muted), const SizedBox(width: 8),
              Text('${functions.length} changed function(s)', style: const TextStyle(color: muted, fontSize: 11)),
            ])),
        ]),
        if (error != null) Padding(padding: const EdgeInsets.only(top: 14),
          child: Text('API connection issue: $error', style: const TextStyle(color: Color(0xFFFFA3B1), fontSize: 12))),
      ]),
    ]),
  );

  Widget repositoryInputCard(bool compact) => Glass(
        radius: 24,
        padding: EdgeInsets.all(compact ? 17 : 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.code_rounded, color: cyan, size: 20),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Analyze a GitHub repository',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: cyan.withOpacity(.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cyan.withOpacity(.25)),
                  ),
                  child: const Text(
                    'PUBLIC REPOS',
                    style: TextStyle(
                      color: cyan,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .7,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste a public GitHub repository URL to inspect its latest commit changes.',
              style: TextStyle(color: muted, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: repositoryController,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => analyzeRepository(),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://github.com/owner/repository',
                hintStyle: const TextStyle(color: muted, fontSize: 12),
                prefixIcon: const Icon(Icons.link_rounded, color: cyan),
                filled: true,
                fillColor: Colors.white.withOpacity(.045),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: cyan, width: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 10,
              runSpacing: 9,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                gradientButton(
                  Icons.travel_explore_rounded,
                  repositoryLoading ? 'Analyzing repository...' : 'Analyze Repository',
                  repositoryLoading || loading ? null : analyzeRepository,
                ),
                if (repositoryLoading)
                  const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cyan),
                  ),
              ],
            ),
          ],
        ),
      );

  Widget stats(bool compact) {
    final data = [
      Stat('Changed files', '${files.length}', Icons.folder_copy_outlined, cyan, 'Files detected'),
      Stat('Changed functions', '${functions.length}', Icons.functions_rounded, violet, 'Function-level changes'),
      Stat('High risk', '${countRisk('HIGH') + countRisk('CRITICAL')}', Icons.warning_amber_rounded, pink, 'Needs attention'),
      Stat('Medium risk', '${countRisk('MEDIUM')}', Icons.shield_outlined, const Color(0xFFFFCE85), 'Review recommended'),
    ];
    return LayoutBuilder(builder: (context, c) => GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: data.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: c.maxWidth < 540 ? 2 : c.maxWidth < 980 ? 2 : 4,
        crossAxisSpacing: 12, mainAxisSpacing: 12, mainAxisExtent: 142),
      itemBuilder: (_, i) => statCard(data[i]),
    ));
  }

  Widget statCard(Stat s) => Glass(radius: 21, padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: s.color.withOpacity(.12),
          borderRadius: BorderRadius.circular(12), border:Border.all(color: s.color.withOpacity(.25))),
          child: Icon(s.icon, color: s.color, size: 20)),
        const Spacer(), Icon(Icons.north_east, size: 14, color: Colors.white.withOpacity(.35)),
      ]),
      const Spacer(),
      Text(s.value, style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w800, height: 1)),
      const SizedBox(height: 7),
      Text(s.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 3),
      Text(s.subtitle, style: const TextStyle(color: muted, fontSize: 10)),
    ]),
  );

  Widget sectionHeader(String title, String subtitle, {Widget? trailing}) => Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.3)),
      const SizedBox(height: 5), Text(subtitle, style: const TextStyle(color: muted, fontSize: 12)),
    ])),
    if (trailing != null) trailing,
  ]);

  Widget resultCard(Map<String, dynamic> m, int index, bool compact) {
    final level = str(m['risk_level'] ?? m['impact_level']?? 'UNKNOWN');
    final color = riskColor(level);
    final name = str(m['changed_function'] ?? m['function'] ?? m['name'] ?? 'Changed function');
    final score = m['risk_score'];
    final affected = listOf(m['affected_functions']);
    final reasons = listOf(m['risk_reasons']);
    final tests = listOf(m['recommended_tests']);
    final summary = str(m['summary'] ?? m['impact_reason']?? m['description'] ?? 'Impact analysis completed for thischange.');
    final action = str(m['recommended_action'] ?? '');

    return Glass(radius: 24, padding: EdgeInsets.all(compact ? 17 : 22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 43, height: 43, decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color.withOpacity(.25), color.withOpacity(.06)]),
            borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(.4))),
            child: Icon(Icons.schema_rounded, color: color)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text('CHANGE #${index.toString().padLeft(2, '0')}', style: const TextStyle(color: muted, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
          ])),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(30),
              border: Border.all(color: color.withOpacity(.4))),
            child: Text(level.toUpperCase(), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900,letterSpacing: .7))),
        ]),
        const SizedBox(height: 17),
        Text(summary, style: const TextStyle(color: Color(0xFFD6DCF2), height: 1.55, fontSize: 13)),
        const SizedBox(height: 16),
        Wrap(spacing: 9, runSpacing: 9, children: [
          metric(Icons.speed_rounded, 'Risk score', score == null ? '—' : '$score/10', color),
          metric(Icons.hub_outlined, 'Affected', '${affected.length}', cyan),
          metric(Icons.fact_check_outlined, 'Test suggestions', '${tests.length}', violet),
        ]),
        if (affected.isNotEmpty || reasons.isNotEmpty || tests.isNotEmpty || action.isNotEmpty) ...[
          const SizedBox(height: 18), Divider(color: Colors.white.withOpacity(.10)), const SizedBox(height: 15),
          LayoutBuilder(builder: (context, c) {
            final sections = <Widget>[
              if (affected.isNotEmpty) detailSection('AFFECTED FUNCTIONS', Icons.account_tree_outlined, affected, cyan),
              if (reasons.isNotEmpty) detailSection('RISK FACTORS', Icons.radar_rounded, reasons, pink),
              if (tests.isNotEmpty) detailSection('RECOMMENDED TESTS', Icons.checklist_rounded, tests, violet),
              if (action.isNotEmpty) actionSection(action),
            ];
            if (c.maxWidth < 650) return Column(children: [
              for (var i = 0; i < sections.length; i++) ...[if (i > 0) const SizedBox(height: 16), sections[i]],
            ]);
            return Wrap(spacing: 20, runSpacing: 18, children: sections.map((w) =>
              SizedBox(width: (c.maxWidth - 20) / 2, child: w)).toList());
          }),
        ],
      ]),
    );
  }

  Widget metric(IconData icon, String label, String value,Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
    decoration: BoxDecoration(color: Colors.white.withOpacity(.035), borderRadius: BorderRadius.circular(13),
      border: Border.all(color: Colors.white.withOpacity(.09))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: color, size: 16), const SizedBox(width: 7),
      Text('$label  ', style: const TextStyle(color: muted, fontSize: 11)),
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)),
    ]),
  );

  Widget detailSection(String title, IconData icon, List<dynamic> items, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, color: color, size: 15), const SizedBox(width: 7),
        Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .8))]),
      const SizedBox(height: 10),
      ...items.take(8).map((item) => Padding(padding: const EdgeInsets.only(bottom: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 6), child: Container(width: 5, height: 5,
            decoration: BoxDecoration(color: color, shape:BoxShape.circle))),
          const SizedBox(width: 9), Expanded(child: Text(str(item),
            style: const TextStyle(color: Color(0xFFD6DCF2), fontSize: 12, height: 1.4))),
        ]))),
    ],
  );

  Widget actionSection(String action) => Container(
    padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: cyan.withOpacity(.06),
      borderRadius: BorderRadius.circular(15), border: Border.all(color: cyan.withOpacity(.18))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.lightbulb_outline_rounded, color: cyan, size: 18), const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('SUGGESTED NEXT STEP', style: TextStyle(color: cyan, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .8)),
        const SizedBox(height: 6), Text(action, style: const TextStyle(color: Color(0xFFE1E8FA), fontSize: 12, height: 1.45)),
      ])),
    ]),
  );

  Widget filesCard() {
    if (files.isEmpty) return Glass(radius: 20, child: Row(children: [
      const Icon(Icons.folder_open_rounded, color: muted),const SizedBox(width: 12),
      Expanded(child: Text(error == null ? 'No changed files were returned by the API.' : 'Files appear here when theAPI is reachable.',
        style: const TextStyle(color: muted, fontSize: 12))),
    ]));
    return Glass(radius: 20, padding: const EdgeInsets.all(8), child: Column(children: files.take(30).toList().asMap().entries.map((e) {
      final v = e.value;
      final name = v is Map ? str(v['path'] ?? v['file'] ?? v['name'] ?? v) : str(v);
      return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(border: e.key == 0 ? null : Border(top: BorderSide(color: Colors.white.withOpacity(.07)))),
        child: Row(children: [
          const Icon(Icons.insert_drive_file_outlined, color: cyan, size: 18), const SizedBox(width: 11),
          Expanded(child: Text(name, style: const TextStyle(color: Color(0xFFDCE4FA), fontSize: 12))),
          const Icon(Icons.chevron_right_rounded, color: muted, size: 18),
        ]));
    }).toList()));
  }

  Widget errorCard() => Padding(padding: const EdgeInsets.only(bottom: 14),
    child: Glass(radius: 20, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.cloud_off_rounded, color: Color(0xFFFFA3B1), size: 24), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Could not load analysis', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 6), Text(error ?? 'Unknown error', style: const TextStyle(color: muted, fontSize: 12)),
        const SizedBox(height: 12), smallButton(Icons.refresh_rounded, 'Try again', loadAnalysis),
      ])),
    ])));

  Widget emptyCard() => Padding(padding: const EdgeInsets.only(bottom: 14),
    child: Glass(radius: 20, child: const Row(children: [
      Icon(Icons.check_circle_outline_rounded, color: cyan, size: 25), SizedBox(width: 12),
      Expanded(child: Text('No changed functions were found in this analysis. Try a repository with a recent Python function change.',
        style: TextStyle(color: muted, height: 1.5, fontSize: 12))),
    ])));

  Widget gradientButton(IconData icon, String label, VoidCallback? onTap) => Opacity(
    opacity: onTap == null ? .65 : 1,
    child: Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(14),
      child: Ink(padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [cyan, violet]),
          borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: violet.withOpacity(.18), blurRadius: 18, offset: const Offset(0, 6))]),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: bg, size: 18), const SizedBox(width: 9),
          Text(label, style: const TextStyle(color: bg, fontWeight: FontWeight.w900, fontSize: 12)),
        ]))),
  )
  );

  Widget smallButton(IconData icon, String label, VoidCallback onTap) => Material(
    color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Ink(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(.15))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: cyan), const SizedBox(width: 7),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
        ]))),
  );
}

class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(17), this.radius = 22});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: BackdropFilter(filter: ImageFilter.blur(sigmaX:18, sigmaY: 18),
      child: Container(padding: padding, decoration: BoxDecoration(
        color: const Color(0xFF202744).withOpacity(.54), borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(.13)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.13), blurRadius: 26, offset: const Offset(0, 12))]),
        child: child)),
  );
}

class GlowBackground extends StatelessWidget {
  const GlowBackground({super.key});
  Widget glow(double size, Color color) => Container(width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withOpacity(.15), Colors.transparent])));
  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: [
    const DecoratedBox(decoration: BoxDecoration(gradient:LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight,
      colors: [Color(0xFF10152D), Color(0xFF151A38), Color(0xFF0C2130)]))),
    Positioned(left: -130, top: -130, child: glow(360, violet.withOpacity(.20))),
    Positioned(right: -180, top: 150, child: glow(430, cyan.withOpacity(.13))),
    Positioned(left: 160, bottom: -200, child: glow(440, pink.withOpacity(.09))),
    const Positioned.fill(child: CustomPaint(painter: DotGridPainter())),
  ]);
}

class DotGridPainter extends CustomPainter {
  const DotGridPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.white.withOpacity(.035);
    for (double x = 0; x < size.width; x += 28) {
      for (double y = 0; y < size.height; y += 28) {
        canvas.drawCircle(Offset(x, y), 1, p);
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Stat {
  const Stat(this.title, this.value, this.icon, this.color, this.subtitle);
  final String title, value, subtitle;
  final IconData icon;
  final Color color;
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((k, v) => MapEntry('$k', v));
  return <String, dynamic>{};
}
List<dynamic> listOf(dynamic value) {
  if (value is List) return List<dynamic>.from(value);
  if (value == null || value == '') return <dynamic>[];
  return <dynamic>[value];
}
String str(dynamic value) {
  if (value == null) return '';
  if (value is String) return value;
  if (value is Map || value is List) return jsonEncode(value);
  return value.toString();
}
Color riskColor(String level) {
  final v = level.toUpperCase();
  if (v.contains('CRITICAL') || v.contains('HIGH')) return pink;
  if (v.contains('MEDIUM')) return const Color(0xFFFFCE85);
  if (v.contains('LOW')) return cyan;
  return violet;
}
