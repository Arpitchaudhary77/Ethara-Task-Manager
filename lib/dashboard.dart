import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'main.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> allProjects = [];
  List<dynamic> filteredProjects = [];
  bool isLoading = true;
  bool isDarkMode = false;
  String userRole = 'member';
  String searchQuery = "";
  String filterPriority = "All";

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    userRole = prefs.getString('role') ?? 'member';
    final data = await ApiService.getProjects();
    setState(() {
      allProjects = data;
      _runFilter();
      isLoading = false;
    });
  }

  void _runFilter() {
    setState(() {
      filteredProjects = allProjects.where((p) {
        final String title = (p['title'] ?? "").toString().toLowerCase();
        final matchesSearch = title.contains(searchQuery.toLowerCase());
        final String priority = (p['priority'] ?? "Medium").toString();
        final matchesPriority = filterPriority == "All" || priority == filterPriority;
        return matchesSearch && matchesPriority;
      }).toList();
    });
  }

  void showCreateDialog() async {
    final titleCtrl = TextEditingController();
    String selectedPriority = 'Medium';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('New Strategic Task', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: "Task Name", border: OutlineInputBorder())),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedPriority,
                  items: ['High', 'Medium', 'Low'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (val) => setDialogState(() => selectedPriority = val!),
                  decoration: const InputDecoration(labelText: 'Priority', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
                  title: Text("Due: ${DateFormat('MMM d, yyyy').format(selectedDate)}"),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isEmpty) return;

                final dateString = selectedDate.toIso8601String();

                await ApiService.createProject(titleCtrl.text, "Planned via OS Interface", selectedPriority, userRole, dateString);

                // Optimistic UI update to ensure it shows correctly even if backend is slow
                setState(() {
                  allProjects.insert(0, {
                    "id": "temp_${DateTime.now().millisecondsSinceEpoch}",
                    "title": titleCtrl.text,
                    "priority": selectedPriority,
                    "dueDate": dateString,
                    "isCompleted": false,
                  });
                  _runFilter();
                });

                Navigator.pop(context);
              },
              child: const Text('Launch Task'),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskDetails(Map<String, dynamic> p) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: _getColor(p['priority']).withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                  child: Text(p['priority'] ?? 'Medium', style: TextStyle(color: _getColor(p['priority']), fontWeight: FontWeight.bold)),
                ),
                if (userRole == 'admin')
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      await ApiService.deleteProject(p['id'].toString());
                      Navigator.pop(context);
                      loadData();
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(p['title'] ?? 'No Title', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(p['description'] ?? 'No description provided.', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
            const SizedBox(height: 32),
            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: isDarkMode ? ThemeData.dark() : ThemeData.light(useMaterial3: true),
      child: Scaffold(
        drawer: _buildProfileDrawer(),
        appBar: AppBar(
          title: const Text("Ethara OS", style: TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode), onPressed: () => setState(() => isDarkMode = !isDarkMode)),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          children: [
            _buildSearchAndFilter(),
            _buildQuickStats(),
            Expanded(
              child: filteredProjects.isEmpty
                  ? const Center(child: Text("No tasks found matching filters"))
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredProjects.length,
                itemBuilder: (context, index) => _buildTaskCard(filteredProjects[index]),
              ),
            ),
          ],
        ),
        floatingActionButton: userRole == 'admin' ? FloatingActionButton.extended(onPressed: showCreateDialog, label: const Text("Add Task"), icon: const Icon(Icons.add)) : null,
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          TextField(
            onChanged: (val) { searchQuery = val; _runFilter(); },
            decoration: InputDecoration(hintText: "Search tasks...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(30))),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ["All", "High", "Medium", "Low"].map((p) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(p),
                  selected: filterPriority == p,
                  onSelected: (val) { filterPriority = p; _runFilter(); },
                ),
              )).toList(),
            ),
          )
        ],
      ),
    );
  }

  // --- UPDATED: REPLACED "DUE IN" WITH "DUE BEFORE" ---
  Widget _buildTaskCard(Map<String, dynamic> p) {
    DateTime dueDate;
    try {
      dueDate = p['dueDate'] != null ? DateTime.parse(p['dueDate']) : DateTime.now().add(const Duration(days: 7));
    } catch (e) {
      dueDate = DateTime.now().add(const Duration(days: 7));
    }

    final String formattedDate = DateFormat('MMM d, yyyy').format(dueDate);
    final bool isDone = p['isCompleted'] ?? false;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.withOpacity(0.2))),
      child: ListTile(
        onTap: () => _showTaskDetails(p),
        title: Text(
            p['title'] ?? 'Untitled',
            style: TextStyle(fontWeight: FontWeight.bold, decoration: isDone ? TextDecoration.lineThrough : null)
        ),
        // This is where we changed the text as you requested
        subtitle: Text(
            "Due before: $formattedDate",
            style: TextStyle(color: isDone ? Colors.grey : Colors.indigo, fontWeight: FontWeight.w600)
        ),
        leading: Checkbox(
          value: isDone,
          onChanged: (val) async {
            setState(() => p['isCompleted'] = val);
            if (p['id'] != null) {
              await ApiService.updateTaskStatus(p['id'].toString(), val!);
            }
          },
        ),
        trailing: Icon(Icons.circle, color: _getColor(p['priority']), size: 14),
      ),
    );
  }

  Widget _buildProfileDrawer() {
    return Drawer(
      child: Column(
        children: [
          const UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.indigo),
            accountName: Text("Arpit Chaudhary", style: TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: Text("arpit.chaudhary@akgec.ac.in"),
            currentAccountPicture: CircleAvatar(backgroundColor: Colors.white, child: Icon(Icons.person, size: 40, color: Colors.indigo)),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text("Settings"),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text("App Settings", style: TextStyle(fontWeight: FontWeight.bold)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const ListTile(leading: Icon(Icons.info_outline), title: Text("Version"), trailing: Text("1.0.5")),
                      const Divider(),
                      SwitchListTile(
                        title: const Text("Dark Mode"),
                        value: isDarkMode,
                        secondary: Icon(isDarkMode ? Icons.dark_mode : Icons.light_mode),
                        onChanged: (val) {
                          setState(() => isDarkMode = val);
                          Navigator.pop(context);
                        },
                      ),
                      const ListTile(leading: Icon(Icons.school_outlined), title: Text("Institution"), subtitle: Text("AKGEC, Ghaziabad")),
                    ],
                  ),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
                ),
              );
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _statTile("Total", allProjects.length.toString(), Colors.indigo),
          const SizedBox(width: 10),
          _statTile("High", allProjects.where((p) => p['priority'] == 'High').length.toString(), Colors.red),
        ],
      ),
    );
  }

  Widget _statTile(String l, String v, Color c) => Expanded(child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Column(children: [Text(l, style: TextStyle(color: c, fontWeight: FontWeight.bold)), Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))])));

  Color _getColor(String? p) => p == "High" ? Colors.red : p == "Medium" ? Colors.orange : Colors.green;
}