import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "https://api-ddo4fjthxq-uc.a.run.app/api";

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"email": email, "password": password}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to login');
  }

  static Future<List<dynamic>> getProjects() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/projects'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<void> createProject(
      String title, String desc, String priority, String role, String dueDate) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "title": title,
        "description": desc,
        "priority": priority,
        "role": role,
        "dueDate": dueDate,
        "isCompleted": false,
      }),
    );
    if (response.statusCode != 201) throw Exception('Failed to create');
  }

  static Future<void> updateTaskStatus(String id, bool isCompleted) async {
    final response = await http.put(
      Uri.parse('$baseUrl/projects/$id'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"isCompleted": isCompleted}),
    );
    if (response.statusCode != 200) throw Exception('Failed to update task');
  }

  static Future<void> deleteProject(String id) async {
    final response = await http.delete(Uri.parse('$baseUrl/projects/$id'));
    if (response.statusCode != 200) throw Exception('Failed to delete');
  }
}