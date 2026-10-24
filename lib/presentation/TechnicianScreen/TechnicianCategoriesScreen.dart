// lib/presentation/TechnicianScreen/TechnicianCategoriesScreen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TechnicianCategoriesScreen extends StatefulWidget {
  const TechnicianCategoriesScreen({super.key});

  @override
  State<TechnicianCategoriesScreen> createState() => _TechnicianCategoriesScreenState();
}

class _TechnicianCategoriesScreenState extends State<TechnicianCategoriesScreen> {
  final List<String> _availableCategories = [
    'AC Repair & Service',
    'Washing Machine Repair',
    'Water Purifier / RO Service',
    'Microwave Repair',
    'Chimney Repair',
    'Geyser Repair',
    'Refrigerator Repair',
    'TV Repair',
    'Air Cooler Repair',
    'Plumbing Service',
    'Electrical Work',
    'Carpenter',
    'CCTV Installation & Services',
    'Water Tank Cleaning',
  ];

  List<String> _selectedCategories = [];
  String _searchQuery = '';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _selectedCategories = List<String>.from(data['categories'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _toggleCategory(String category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
    });
  }

  Future<void> _saveCategories() async {
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'categories': _selectedCategories,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service Categories updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error saving: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const darkBlue = Color(0xFF0C1B4D);
    const primaryBlue = Color(0xFF2563EB);

    // Sort: Selected categories float to the top
    final filteredCategories = _availableCategories.where((cat) {
      return cat.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    filteredCategories.sort((a, b) {
      bool aSelected = _selectedCategories.contains(a);
      bool bSelected = _selectedCategories.contains(b);
      if (aSelected && !bSelected) return -1;
      if (!aSelected && bSelected) return 1;
      return a.compareTo(b);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Service Categories',
          style: TextStyle(fontWeight: FontWeight.bold, color: darkBlue),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: darkBlue),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ========================================================
                // FULL PAGE SCROLLABLE CONTENT (UPPER + LOWER TOGETHER)
                // ========================================================
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. ACTIVE / SELECTED CATEGORIES SECTION
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Your Active Categories',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: darkBlue,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: primaryBlue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_selectedCategories.length} Selected',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: primaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (_selectedCategories.isEmpty)
                                Text(
                                  'No categories selected yet. Please select from the list below.',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                )
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _selectedCategories.map((cat) {
                                    return Chip(
                                      label: Text(
                                        cat,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      backgroundColor: primaryBlue,
                                      deleteIcon: const Icon(Icons.close, size: 16, color: Colors.white),
                                      onDeleted: () => _toggleCategory(cat),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),

                        const Divider(height: 1),

                        // 2. SEARCH BAR
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Search categories...',
                              prefixIcon: const Icon(Icons.search, color: Colors.grey),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),

                        // 3. CATEGORIES SELECTION LIST (SCROLLABLE WITH PAGE)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: filteredCategories.isEmpty
                              ? const Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Center(child: Text('No categories found')),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: filteredCategories.length,
                                  itemBuilder: (context, index) {
                                    final category = filteredCategories[index];
                                    final isSelected = _selectedCategories.contains(category);

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected ? primaryBlue : Colors.grey.shade200,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: CheckboxListTile(
                                        title: Text(
                                          category,
                                          style: TextStyle(
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSelected ? darkBlue : Colors.black87,
                                          ),
                                        ),
                                        value: isSelected,
                                        activeColor: primaryBlue,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        onChanged: (_) => _toggleCategory(category),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),

                // ========================================================
                // SAVE BUTTON AT BOTTOM
                // ========================================================
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveCategories,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
