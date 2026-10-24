// lib/presentation/TechnicianScreen/TechnicianAreasScreen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TechnicianAreasScreen extends StatefulWidget {
  const TechnicianAreasScreen({super.key});

  @override
  State<TechnicianAreasScreen> createState() => _TechnicianAreasScreenState();
}

class _TechnicianAreasScreenState extends State<TechnicianAreasScreen> {
  List<String> _pincodes = [];
  final TextEditingController _pincodeController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;

  // Suggested / Common area pincodes
  final List<String> _suggestedPincodes = [
    '390001',
    '390002',
    '390007',
    '390011',
    '390015',
    '390019',
    '390020',
  ];

  @override
  void initState() {
    super.initState();
    _loadPincodes();
  }

  @override
  void dispose() {
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _loadPincodes() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _pincodes = List<String>.from(data['pincodes'] ?? []);
        });
      }
    } catch (e) {
      debugPrint('Error loading pincodes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _addPincode([String? customPincode]) {
    final pincode = (customPincode ?? _pincodeController.text).trim();

    if (pincode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid pincode')),
      );
      return;
    }

    if (pincode.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pincode must be 4 digits')),
      );
      return;
    }

    if (_pincodes.contains(pincode)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pincode $pincode is already added')),
      );
      return;
    }

    setState(() {
      _pincodes.add(pincode);
      if (customPincode == null) {
        _pincodeController.clear();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pincode $pincode added'),
        duration: const Duration(seconds: 1),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _removePincode(String pincode) {
    setState(() {
      _pincodes.remove(pincode);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pincode $pincode removed'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _savePincodes() async {
    if (_pincodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one area/pincode')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'pincodes': _pincodes,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service Areas updated successfully!'),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Service Areas',
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
                        // 1. ADD PINCODE INPUT SECTION
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.white,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Add New Service Area / Pincode',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: darkBlue,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _pincodeController,
                                      keyboardType: TextInputType.number,
                                      maxLength: 4,
                                      decoration: InputDecoration(
                                        hintText: 'Enter 4-digit Pincode',
                                        counterText: '',
                                        filled: true,
                                        fillColor: const Color(0xFFF8FAFC),
                                        prefixIcon: const Icon(Icons.location_on_outlined, color: primaryBlue),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(12),
                                          borderSide: BorderSide(color: Colors.grey.shade300),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: () => _addPincode(),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Add'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const Divider(height: 1),

                        // 2. SUGGESTED PINCODES CHIPS
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Quick Add Suggested Pincodes:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: _suggestedPincodes.map((pin) {
                                  final isAlreadyAdded = _pincodes.contains(pin);
                                  return ActionChip(
                                    avatar: Icon(
                                      isAlreadyAdded ? Icons.check : Icons.add_location_alt_outlined,
                                      size: 14,
                                      color: isAlreadyAdded ? Colors.green : primaryBlue,
                                    ),
                                    label: Text(
                                      pin,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isAlreadyAdded ? Colors.green : darkBlue,
                                      ),
                                    ),
                                    backgroundColor: isAlreadyAdded ? Colors.green.shade50 : Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: isAlreadyAdded ? Colors.green.shade300 : Colors.grey.shade300,
                                      ),
                                    ),
                                    onPressed: () {
                                      if (!isAlreadyAdded) {
                                        _addPincode(pin);
                                      } else {
                                        _removePincode(pin);
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        // 3. ACTIVE SERVICE PINCODES LIST (WITH DELETE BUTTONS)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Active Service Areas',
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
                                  '${_pincodes.length} Active',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: primaryBlue,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _pincodes.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(height: 32),
                                      Icon(Icons.location_off_outlined, size: 48, color: Colors.grey.shade400),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No service areas added yet.',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Add a pincode above to start receiving tasks.',
                                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                                      ),
                                      const SizedBox(height: 32),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _pincodes.length,
                                  itemBuilder: (context, index) {
                                    final pin = _pincodes[index];
                                    return Card(
                                      color: Colors.white,
                                      elevation: 0,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(color: Colors.grey.shade200),
                                      ),
                                      child: ListTile(
                                        leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: primaryBlue.withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.location_on, color: primaryBlue, size: 20),
                                        ),
                                        title: Text(
                                          'Pincode: $pin',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: darkBlue,
                                          ),
                                        ),
                                        subtitle: const Text(
                                          'Active for task matching',
                                          style: TextStyle(fontSize: 12, color: Colors.grey),
                                        ),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          tooltip: 'Remove Pincode',
                                          onPressed: () => _removePincode(pin),
                                        ),
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
                      onPressed: _isSaving ? null : _savePincodes,
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
