import 'package:flutter/material.dart';

class Admin extends StatelessWidget {
  const Admin({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D0F36),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AdminButton(
              icon: Icons.add,
              label: "Add Project",
              color: Color(0xFF0D0F36),
              onTap: () {
                // Navigate to your Dashboard page
              },
            ),
            const SizedBox(height: 6),
            AdminButton(
              icon: Icons.edit,
              label: "Edit Project",
              color: Color(0xFF0D0F36),
              onTap: () {
                // Navigate to your Dashboard page
              },
            ),
            const SizedBox(height: 6),
            AdminButton(
              icon: Icons.delete,
              label: "Delete Project",
              color: Color(0xFF0D0F36),
              onTap: () {
                // Navigate to your Dashboard page
              },
            ),
            const SizedBox(height: 6),
            AdminButton(
              icon: Icons.person_add,
              label: "Add User",
              color: Color(0xFF0D0F36),
              onTap: () {
                // Navigate to your Dashboard page
              },
            ),
            const SizedBox(height: 6),
            AdminButton(
              icon: Icons.dashboard,
              label: "Dashboard",
              color: Color(0xFF0D0F36),
              onTap: () {
                // Navigate to your Dashboard page
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Reusable button widget
class AdminButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const AdminButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 24),
      label: Text(label, style: const TextStyle(fontSize: 16)),
      onPressed: onTap,
    );
  }
}
