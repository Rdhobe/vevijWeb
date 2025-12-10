import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Edit Inventory Page Class
class EditInventoryPage extends StatefulWidget {
  final String projectId;
  final String itemId;
  final String materialName;

  const EditInventoryPage({
    super.key,
    required this.projectId,
    required this.itemId,
    required this.materialName,
  });

  @override
  State<EditInventoryPage> createState() => _EditInventoryPageState();
}

class _EditInventoryPageState extends State<EditInventoryPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _materialNameController = TextEditingController();
  final _requiredQtyController = TextEditingController();
  final _reasonController = TextEditingController();
  final _balIssueQtyController = TextEditingController();
  final _usedQtyController = TextEditingController();

  // Tab controller
  late TabController _tabController;

  String _selectedUom = 'PCS';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _formReady = false;

  Map<String, dynamic> _originalData = {};
  List<Map<String, dynamic>> _receivedEntries = [];
  List<Map<String, dynamic>> _issuedEntries = [];

  final List<String> _uomOptions = [
    'PCS',
    'KG',
    'MT',
    'L',
    'M',
    'M2',
    'M3',
    'BOX',
    'BAG',
    'TON',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Use post-frame callback to ensure widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInventoryItem();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Mark form as ready when dependencies are loaded
    if (!_formReady && !_isLoading) {
      _formReady = true;
    }
  }

  @override
  void dispose() {
    _materialNameController.dispose();
    _requiredQtyController.dispose();
    _reasonController.dispose();
    _balIssueQtyController.dispose();
    _usedQtyController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInventoryItem() async {
    if (!mounted) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('inventory')
          .doc(widget.itemId)
          .get();

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data()!;
        
        // Initialize with default values
        _originalData = {
          'materialName': data['materialName']?.toString() ?? '',
          'requiredQty': _safeParseInt(data['requiredQty']),
          'totalReceivedQty': _safeParseInt(data['totalReceivedQty']),
          'totalIssuedQty': _safeParseInt(data['totalIssuedQty']),
          'balIssueQty': _safeParseInt(data['balIssueQty']),
          'usedQty': _safeParseInt(data['usedQty']),
          'balanceQty': _safeParseInt(data['balanceQty']),
          'uom': data['uom']?.toString() ?? 'PCS',
          'receivedEntries': data['receivedEntries'] ?? [],
          'issuedEntries': data['issuedEntries'] ?? [],
        };

        // Convert entries to proper format
        _receivedEntries = List<Map<String, dynamic>>.from(
          _originalData['receivedEntries'] as List,
        ).map((entry) {
          return {
            'challanNo': entry['challanNo']?.toString() ?? '',
            'date': entry['date']?.toString() ?? '',
            'qty': _safeParseInt(entry['qty']),
            'id': entry['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          };
        }).toList();

        _issuedEntries = List<Map<String, dynamic>>.from(
          _originalData['issuedEntries'] as List,
        ).map((entry) {
          return {
            'challanNo': entry['challanNo']?.toString() ?? '',
            'date': entry['date']?.toString() ?? '',
            'qty': _safeParseInt(entry['qty']),
            'id': entry['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          };
        }).toList();

        if (mounted) {
          setState(() {
            _materialNameController.text = _originalData['materialName'] as String;
            _requiredQtyController.text = _originalData['requiredQty'].toString();
            _balIssueQtyController.text = _originalData['balIssueQty'].toString();
            _usedQtyController.text = _originalData['usedQty'].toString();
            _selectedUom = _originalData['uom'] as String;
            _isLoading = false;
            _formReady = true;
          });
        }
      } else {
        // Document doesn't exist
        if (mounted) {
          _showSnackBar('Inventory item not found', Colors.red);
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      print('Load error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _formReady = true;
        });
        _showSnackBar('Error loading inventory item', Colors.red);
      }
    }
  }

  int _safeParseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed ?? 0;
    }
    if (value is double) return value.toInt();
    return 0;
  }

  Future<void> _saveChanges() async {
    // Check if form is ready and mounted
    if (!_formReady || !mounted) {
      _showSnackBar('Form is not ready. Please wait...', Colors.orange);
      return;
    }
    
    // Check if form key exists
    if (_formKey.currentState == null) {
      _showSnackBar('Please wait for form to load...', Colors.orange);
      return;
    }
    
    // Validate form
    if (!_formKey.currentState!.validate()) {
      _showSnackBar('Please fix validation errors', Colors.red);
      return;
    }

    if (!mounted) return;

    setState(() => _isSaving = true);
    
    try {
      // Parse input values safely
      final requiredQty = int.tryParse(_requiredQtyController.text) ?? 
                         _safeParseInt(_originalData['requiredQty']);
      
      final usedQty = int.tryParse(_usedQtyController.text) ?? 
                     _safeParseInt(_originalData['usedQty']);
      
      final balIssueQty = int.tryParse(_balIssueQtyController.text) ?? 
                         _safeParseInt(_originalData['balIssueQty']);

      // Calculate totals from entries
      final totalReceivedQty = _receivedEntries.fold<int>(0, (acc, entry) {
        return acc + (entry['qty'] as int? ?? 0);
      });

      final totalIssuedQty = _issuedEntries.fold<int>(0, (acc, entry) {
        return acc + (entry['qty'] as int? ?? 0);
      });

      // Validate data consistency
      if (requiredQty < totalReceivedQty) {
        if (mounted) {
          _showSnackBar(
            'Error: Received quantity ($totalReceivedQty) exceeds required quantity ($requiredQty)',
            Colors.red,
          );
          setState(() => _isSaving = false);
        }
        return;
      }

      if (totalReceivedQty < totalIssuedQty) {
        if (mounted) {
          _showSnackBar(
            'Error: Issued quantity ($totalIssuedQty) exceeds received quantity ($totalReceivedQty)',
            Colors.red,
          );
          setState(() => _isSaving = false);
        }
        return;
      }

      // Calculate balance quantity
      final balanceQty = totalReceivedQty - totalIssuedQty - usedQty;
      
      // Validate balance can't be negative
      if (balanceQty < 0) {
        if (mounted) {
          _showSnackBar(
            'Error: Balance quantity cannot be negative ($balanceQty)',
            Colors.red,
          );
          setState(() => _isSaving = false);
        }
        return;
      }

      // Prepare updated data
      final updatedData = {
        'materialName': _materialNameController.text.trim(),
        'requiredQty': requiredQty,
        'totalReceivedQty': totalReceivedQty,
        'totalIssuedQty': totalIssuedQty,
        'balIssueQty': balIssueQty,
        'usedQty': usedQty,
        'balanceQty': balanceQty,
        'uom': _selectedUom,
        'receivedEntries': _receivedEntries,
        'issuedEntries': _issuedEntries,
        'updatedAt': Timestamp.now(),
      };

      final docRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('inventory')
          .doc(widget.itemId);

      // Get current document to check structure
      final snapshot = await docRef.get();
      
      try {
        if (!snapshot.exists) {
          // Document doesn't exist - create it with all fields
          await docRef.set({
            ...updatedData,
            'createdAt': Timestamp.now(),
            'projectId': widget.projectId,
          });
        } else {
          // Document exists - update it
          await docRef.update(updatedData);
        }

        if (mounted) {
          _showSnackBar('Inventory updated successfully', Colors.green);
          Navigator.of(context).pop(true);
        }
        
      } on FirebaseException catch (e) {
        print('Firebase error: $e');
        if (mounted) {
          _showSnackBar('Database error: ${e.message}', Colors.red);
        }
      } catch (e) {
        print('Update error: $e');
        if (mounted) {
          _showSnackBar('Error saving changes', Colors.red);
        }
      }
      
    } catch (e) {
      print('General error in saveChanges: $e');
      if (mounted) {
        _showSnackBar('An unexpected error occurred', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteReceivedEntry(int index, Map<String, dynamic> entry) async {
    if (index < 0 || index >= _receivedEntries.length) return;
    
    // Show confirmation dialog before deleting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Received Entry'),
        content: const Text(
          'Are you sure you want to delete this received entry? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    
    try {
      // Update local state first for immediate UI feedback
      final deletedEntry = _receivedEntries[index];
      setState(() {
        _receivedEntries.removeAt(index);
      });

      // Calculate new totals
      final totalReceivedQty = _receivedEntries.fold<int>(0, (acc, e) {
        return acc + (e['qty'] as int? ?? 0);
      });

      final totalIssuedQty = _issuedEntries.fold<int>(0, (acc, e) {
        return acc + (e['qty'] as int? ?? 0);
      });

      final usedQty = int.tryParse(_usedQtyController.text) ?? 
                    _safeParseInt(_originalData['usedQty']);
      final balanceQty = totalReceivedQty - totalIssuedQty - usedQty;

      // Update Firestore
      final docRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('inventory')
          .doc(widget.itemId);

      await docRef.update({
        'receivedEntries': _receivedEntries,
        'totalReceivedQty': totalReceivedQty,
        'balanceQty': balanceQty,
        'updatedAt': Timestamp.now(),
      });

      if (mounted) {
        _showSnackBar('Received entry deleted successfully', Colors.green);
      }
      
    } catch (e) {
      print('Error deleting received entry: $e');
      // Revert local state if Firestore update fails
      if (mounted) {
        setState(() {
          // Try to restore the deleted entry
          if (index <= _receivedEntries.length) {
            _receivedEntries.insert(index, entry);
          }
        });
        _showSnackBar('Failed to delete entry', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteIssuedEntry(int index, Map<String, dynamic> entry) async {
    if (index < 0 || index >= _issuedEntries.length) return;
    
    // Show confirmation dialog before deleting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Issued Entry'),
        content: const Text(
          'Are you sure you want to delete this issued entry? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isSaving = true);
    
    try {
      // Update local state first for immediate UI feedback
      final deletedEntry = _issuedEntries[index];
      setState(() {
        _issuedEntries.removeAt(index);
      });

      // Calculate new totals
      final totalReceivedQty = _receivedEntries.fold<int>(0, (acc, e) {
        return acc + (e['qty'] as int? ?? 0);
      });

      final totalIssuedQty = _issuedEntries.fold<int>(0, (acc, e) {
        return acc + (e['qty'] as int? ?? 0);
      });

      final usedQty = int.tryParse(_usedQtyController.text) ?? 
                    _safeParseInt(_originalData['usedQty']);
      final balanceQty = totalReceivedQty - totalIssuedQty - usedQty;

      // Update Firestore
      final docRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('inventory')
          .doc(widget.itemId);

      await docRef.update({
        'issuedEntries': _issuedEntries,
        'totalIssuedQty': totalIssuedQty,
        'balanceQty': balanceQty,
        'updatedAt': Timestamp.now(),
      });

      if (mounted) {
        _showSnackBar('Issued entry deleted successfully', Colors.green);
      }
      
    } catch (e) {
      print('Error deleting issued entry: $e');
      // Revert local state if Firestore update fails
      if (mounted) {
        setState(() {
          // Try to restore the deleted entry
          if (index <= _issuedEntries.length) {
            _issuedEntries.insert(index, entry);
          }
        });
        _showSnackBar('Failed to delete entry', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _addOrEditReceivedEntry({
    String? entryId,
    String? initialChallanNo,
    String? initialDate,
    int? initialQty,
    bool isEditing = false,
  }) async {
    final challanController = TextEditingController(text: initialChallanNo ?? '');
    final dateController = TextEditingController(text: initialDate ?? '');
    final qtyController = TextEditingController(text: initialQty?.toString() ?? '');

    String? errorMessage;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? 'Edit Received Entry' : 'Add Received Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: challanController,
                decoration: const InputDecoration(
                  labelText: 'Challan No',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (DD.MM.YYYY)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  border: const OutlineInputBorder(),
                  errorText: errorMessage,
                  helperText: _getQuantityHelperText(true),
                  helperMaxLines: 2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    errorMessage = _validateQuantity(value, true, isEditing);
                  });
                },
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                    border: flutter.Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[600], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: errorMessage != null
                  ? null
                  : () {
                      final challanNo = challanController.text.trim();
                      final date = dateController.text.trim();
                      final qty = int.tryParse(qtyController.text) ?? 0;

                      if (challanNo.isNotEmpty && date.isNotEmpty && qty > 0) {
                        Navigator.of(context).pop({
                          'challanNo': challanNo,
                          'date': date,
                          'qty': qty,
                          'id': entryId ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        });
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    setState(() => _isSaving = true);
    
    try {
      List<Map<String, dynamic>> newReceivedEntries;
      
      if (isEditing && entryId != null) {
        // Find and update existing entry
        newReceivedEntries = _receivedEntries.map((entry) {
          if (entry['id'] == entryId) {
            return {
              ...entry,
              'challanNo': result['challanNo'],
              'date': result['date'],
              'qty': result['qty'],
            };
          }
          return entry;
        }).toList();
      } else {
        // Add new entry
        newReceivedEntries = [..._receivedEntries, result];
      }

      // Calculate new totals
      final totalReceivedQty = newReceivedEntries.fold<int>(0, (acc, entry) {
        return acc + (entry['qty'] as int? ?? 0);
      });

      final totalIssuedQty = _issuedEntries.fold<int>(0, (acc, entry) {
        return acc + (entry['qty'] as int? ?? 0);
      });

      final usedQty = int.tryParse(_usedQtyController.text) ?? 
                    _safeParseInt(_originalData['usedQty']);
      final balanceQty = totalReceivedQty - totalIssuedQty - usedQty;

      // Update Firestore
      final docRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('inventory')
          .doc(widget.itemId);

      await docRef.update({
        'receivedEntries': newReceivedEntries,
        'totalReceivedQty': totalReceivedQty,
        'balanceQty': balanceQty,
        'updatedAt': Timestamp.now(),
      });

      // Update local state
      if (mounted) {
        setState(() {
          _receivedEntries = newReceivedEntries;
        });
        _showSnackBar(
          isEditing ? 'Received entry updated successfully' : 'Received entry added successfully',
          Colors.green,
        );
      }
      
    } catch (e) {
      print('Error ${isEditing ? 'updating' : 'adding'} received entry: $e');
      if (mounted) {
        _showSnackBar('Failed to ${isEditing ? 'update' : 'add'} entry', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _addOrEditIssuedEntry({
    String? entryId,
    String? initialChallanNo,
    String? initialDate,
    int? initialQty,
    bool isEditing = false,
  }) async {
    final challanController = TextEditingController(text: initialChallanNo ?? '');
    final dateController = TextEditingController(text: initialDate ?? '');
    final qtyController = TextEditingController(text: initialQty?.toString() ?? '');

    String? errorMessage;

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? 'Edit Issued Entry' : 'Add Issued Entry'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: challanController,
                decoration: const InputDecoration(
                  labelText: 'Challan No',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (DD.MM.YYYY)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  border: const OutlineInputBorder(),
                  errorText: errorMessage,
                  helperText: _getQuantityHelperText(false),
                  helperMaxLines: 2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                onChanged: (value) {
                  setState(() {
                    errorMessage = _validateQuantity(value, false, isEditing);
                  });
                },
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(4),
                    border: flutter.Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[600], size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorMessage!,
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: errorMessage != null
                  ? null
                  : () {
                      final challanNo = challanController.text.trim();
                      final date = dateController.text.trim();
                      final qty = int.tryParse(qtyController.text) ?? 0;

                      if (challanNo.isNotEmpty && date.isNotEmpty && qty > 0) {
                        Navigator.of(context).pop({
                          'challanNo': challanNo,
                          'date': date,
                          'qty': qty,
                          'id': entryId ?? DateTime.now().millisecondsSinceEpoch.toString(),
                        });
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    setState(() => _isSaving = true);
    
    try {
      List<Map<String, dynamic>> newIssuedEntries;
      
      if (isEditing && entryId != null) {
        // Find and update existing entry
        newIssuedEntries = _issuedEntries.map((entry) {
          if (entry['id'] == entryId) {
            return {
              ...entry,
              'challanNo': result['challanNo'],
              'date': result['date'],
              'qty': result['qty'],
            };
          }
          return entry;
        }).toList();
      } else {
        // Add new entry
        newIssuedEntries = [..._issuedEntries, result];
      }

      // Calculate new totals
      final totalReceivedQty = _receivedEntries.fold<int>(0, (acc, entry) {
        return acc + (entry['qty'] as int? ?? 0);
      });

      final totalIssuedQty = newIssuedEntries.fold<int>(0, (acc, entry) {
        return acc + (entry['qty'] as int? ?? 0);
      });

      final usedQty = int.tryParse(_usedQtyController.text) ?? 
                    _safeParseInt(_originalData['usedQty']);
      final balanceQty = totalReceivedQty - totalIssuedQty - usedQty;

      // Update Firestore
      final docRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('inventory')
          .doc(widget.itemId);

      await docRef.update({
        'issuedEntries': newIssuedEntries,
        'totalIssuedQty': totalIssuedQty,
        'balanceQty': balanceQty,
        'updatedAt': Timestamp.now(),
      });

      // Update local state
      if (mounted) {
        setState(() {
          _issuedEntries = newIssuedEntries;
        });
        _showSnackBar(
          isEditing ? 'Issued entry updated successfully' : 'Issued entry added successfully',
          Colors.green,
        );
      }
      
    } catch (e) {
      print('Error ${isEditing ? 'updating' : 'adding'} issued entry: $e');
      if (mounted) {
        _showSnackBar('Failed to ${isEditing ? 'update' : 'add'} entry', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontSize: 14)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String? _validateQuantity(String value, bool isReceived, bool isEditing) {
    final qty = int.tryParse(value);
    if (qty == null || qty <= 0) {
      return qty == null
          ? 'Please enter a valid number'
          : 'Quantity must be greater than 0';
    }

    final requiredQty = int.tryParse(_requiredQtyController.text) ??
                      _safeParseInt(_originalData['requiredQty']);

    if (isReceived) {
      // For received entries
      final currentTotalReceived = _receivedEntries.fold<int>(0, (acc, entry) {
        final entryQty = entry['qty'] as int?;
        return entryQty != null ? acc + entryQty : acc;
      });

      if (qty > requiredQty) {
        return 'Cannot exceed required quantity ($requiredQty)';
      }
    } else {
      // For issued entries - validate against available quantity
      final currentTotalReceived = _receivedEntries.fold<int>(0, (acc, entry) {
        final entryQty = entry['qty'] as int?;
        return entryQty != null ? acc + entryQty : acc;
      });
      
      final currentUsedQty = int.tryParse(_usedQtyController.text) ??
                           _safeParseInt(_originalData['usedQty']);
                           
      final currentTotalIssued = _issuedEntries.fold<int>(0, (acc, entry) {
        final entryQty = entry['qty'] as int?;
        return entryQty != null ? acc + entryQty : acc;
      });

      final availableQty = currentTotalReceived - currentTotalIssued - currentUsedQty;

      if (qty > availableQty) {
        return 'Cannot issue more than available quantity ($availableQty)';
      }
    }

    return null;
  }

  String _getQuantityHelperText(bool isReceived) {
    if (isReceived) {
      final requiredQty = int.tryParse(_requiredQtyController.text) ??
                         _safeParseInt(_originalData['requiredQty']);
      final currentTotalReceived = _receivedEntries.fold<int>(0, (acc, entry) {
        final entryQty = entry['qty'] as int?;
        return entryQty != null ? acc + entryQty : acc;
      });
      final remaining = requiredQty - currentTotalReceived;

      return 'Required: $requiredQty, Received: $currentTotalReceived, Remaining: $remaining';
    } else {
      final currentTotalReceived = _receivedEntries.fold<int>(0, (acc, entry) {
        final entryQty = entry['qty'] as int?;
        return entryQty != null ? acc + entryQty : acc;
      });
      
      final currentUsedQty = int.tryParse(_usedQtyController.text) ??
                           _safeParseInt(_originalData['usedQty']);
                           
      final currentTotalIssued = _issuedEntries.fold<int>(0, (acc, entry) {
        final entryQty = entry['qty'] as int?;
        return entryQty != null ? acc + entryQty : acc;
      });
      
      final available = currentTotalReceived - currentTotalIssued - currentUsedQty;

      return 'Available to issue: $available (Received: $currentTotalReceived, Used: $currentUsedQty, Issued: $currentTotalIssued)';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Edit Inventory'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          if (!_isLoading && _formReady)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _isSaving ? null : _saveChanges,
                icon: _isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
                        ),
                      )
                    : const Icon(Icons.save, size: 18),
                label: Text(_isSaving ? 'Saving...' : 'Save'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[600],
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
        bottom: _isLoading
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue[600],
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: Colors.blue[600],
                  tabs: const [
                    Tab(icon: Icon(Icons.edit, size: 18), text: 'Basic Info'),
                    Tab(icon: Icon(Icons.input, size: 18), text: 'Received'),
                    Tab(icon: Icon(Icons.output, size: 18), text: 'Issued'),
                  ],
                ),
              ),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading inventory data...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBasicInfoTab(isDesktop),
                _buildReceivedEntriesTab(),
                _buildIssuedEntriesTab(),
              ],
            ),
    );
  }

  Widget _buildBasicInfoTab(bool isDesktop) {
    // Calculate current totals
    final totalReceivedQty = _receivedEntries.fold<int>(0, (acc, entry) {
      final entryQty = entry['qty'] as int?;
      return entryQty != null ? acc + entryQty : acc;
    });
    
    final totalIssuedQty = _issuedEntries.fold<int>(0, (acc, entry) {
      final entryQty = entry['qty'] as int?;
      return entryQty != null ? acc + entryQty : acc;
    });
    
    final usedQty = int.tryParse(_usedQtyController.text) ?? 
                  _safeParseInt(_originalData['usedQty']);
    final balanceQty = totalReceivedQty - totalIssuedQty - usedQty;
    
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 800 : double.infinity,
          ),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 24 : 16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Main Form Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.edit,
                                  color: Colors.blue[600],
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Material Information',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Material Name
                          _buildCompactTextField(
                            controller: _materialNameController,
                            label: 'Material Name',
                            icon: Icons.inventory_2_outlined,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Quantities Row
                          if (isDesktop) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactTextField(
                                    controller: _requiredQtyController,
                                    label: 'Required Qty',
                                    icon: Icons.directions_run,
                                    keyboardType: TextInputType.number,
                                    validator: _quantityValidator,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInfoDisplay(
                                    label: 'Total Received Qty',
                                    value: totalReceivedQty.toString(),
                                    icon: Icons.input,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: _buildCompactDropdown(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactTextField(
                                    controller: _balIssueQtyController,
                                    label: 'Balance Issue Qty',
                                    icon: Icons.balance,
                                    keyboardType: TextInputType.number,
                                    validator: _quantityValidator,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildCompactTextField(
                                    controller: _usedQtyController,
                                    label: 'Used Qty',
                                    icon: Icons.done,
                                    keyboardType: TextInputType.number,
                                    validator: _quantityValidator,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 1,
                                  child: _buildInfoDisplay(
                                    label: 'Current Balance Qty',
                                    value: balanceQty.toString(),
                                    icon: Icons.inventory_2,
                                    color: balanceQty < 0 ? Colors.red : Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: _buildCompactTextField(
                                    controller: _requiredQtyController,
                                    label: 'Required Qty',
                                    icon: Icons.directions_run,
                                    keyboardType: TextInputType.number,
                                    validator: _quantityValidator,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: _buildCompactDropdown()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoDisplay(
                                    label: 'Total Received',
                                    value: totalReceivedQty.toString(),
                                    icon: Icons.input,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildInfoDisplay(
                                    label: 'Current Balance',
                                    value: balanceQty.toString(),
                                    icon: Icons.inventory_2,
                                    color: balanceQty < 0 ? Colors.red : Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildCompactTextField(
                                    controller: _balIssueQtyController,
                                    label: 'Balance Issue',
                                    icon: Icons.balance,
                                    keyboardType: TextInputType.number,
                                    validator: _quantityValidator,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildCompactTextField(
                                    controller: _usedQtyController,
                                    label: 'Used Qty',
                                    icon: Icons.done,
                                    keyboardType: TextInputType.number,
                                    validator: _quantityValidator,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Reason field (optional)
                          _buildCompactTextField(
                            controller: _reasonController,
                            label: 'Notes (Optional)',
                            icon: Icons.note_alt_outlined,
                            maxLines: 2,
                            hint: 'Add any notes...',
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Current Info Card
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.blue[600],
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Original Values',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (isDesktop) ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'Total Issued',
                                    '${_safeParseInt(_originalData['totalIssuedQty'])}',
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'Used Qty',
                                    '${_safeParseInt(_originalData['usedQty'])}',
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'UOM',
                                    _originalData['uom']?.toString() ?? 'N/A',
                                  ),
                                ),
                              ],
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'Total Issued',
                                    '${_safeParseInt(_originalData['totalIssuedQty'])}',
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'Used Qty',
                                    '${_safeParseInt(_originalData['usedQty'])}',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildInfoItem(
                              'Unit of Measurement',
                              _originalData['uom']?.toString() ?? 'N/A',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceivedEntriesTab() {
    final totalReceivedQty = _receivedEntries.fold<int>(0, (acc, entry) {
      final entryQty = entry['qty'] as int?;
      return entryQty != null ? acc + entryQty : acc;
    });
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.input, color: Colors.green[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Received Entries',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Total: ${_receivedEntries.length} entries • $totalReceivedQty ${_selectedUom}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _addOrEditReceivedEntry(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _receivedEntries.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No received entries yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Click "Add Entry" to add received items',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _receivedEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _receivedEntries[index];
                      final challanNo = entry['challanNo']?.toString() ?? 'N/A';
                      final date = entry['date']?.toString() ?? 'N/A';
                      final qty = entry['qty'] as int? ?? 0;
                      final entryId = entry['id']?.toString() ?? '';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.green[100],
                            child: Icon(
                              Icons.receipt,
                              color: Colors.green[600],
                            ),
                          ),
                          title: Text('Challan: $challanNo'),
                          subtitle: Text(
                            'Date: $date • Qty: $qty ${_selectedUom}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: _isSaving 
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                                        ),
                                      )
                                    : const Icon(Icons.edit, size: 18),
                                onPressed: _isSaving ? null : () => _addOrEditReceivedEntry(
                                  entryId: entryId,
                                  initialChallanNo: challanNo,
                                  initialDate: date,
                                  initialQty: qty,
                                  isEditing: true,
                                ),
                              ),
                              IconButton(
                                icon: _isSaving
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                                        ),
                                      )
                                    : const Icon(Icons.delete, size: 18),
                                color: Colors.red,
                                onPressed: _isSaving ? null : () => _deleteReceivedEntry(index, entry),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssuedEntriesTab() {
    final totalIssuedQty = _issuedEntries.fold<int>(0, (acc, entry) {
      final entryQty = entry['qty'] as int?;
      return entryQty != null ? acc + entryQty : acc;
    });
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.output, color: Colors.orange[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Issued Entries',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Total: ${_issuedEntries.length} entries • $totalIssuedQty ${_selectedUom}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : () => _addOrEditIssuedEntry(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Entry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _issuedEntries.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No issued entries yet',
                          style: TextStyle(color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Click "Add Entry" to add issued items',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _issuedEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _issuedEntries[index];
                      final challanNo = entry['challanNo']?.toString() ?? 'N/A';
                      final date = entry['date']?.toString() ?? 'N/A';
                      final qty = entry['qty'] as int? ?? 0;
                      final entryId = entry['id']?.toString() ?? '';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.orange[100],
                            child: Icon(
                              Icons.receipt_long,
                              color: Colors.orange[600],
                            ),
                          ),
                          title: Text('Challan: $challanNo'),
                          subtitle: Text(
                            'Date: $date • Qty: $qty ${_selectedUom}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: _isSaving
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                                        ),
                                      )
                                    : const Icon(Icons.edit, size: 18),
                                onPressed: _isSaving ? null : () => _addOrEditIssuedEntry(
                                  entryId: entryId,
                                  initialChallanNo: challanNo,
                                  initialDate: date,
                                  initialQty: qty,
                                  isEditing: true,
                                ),
                              ),
                              IconButton(
                                icon: _isSaving
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
                                        ),
                                      )
                                    : const Icon(Icons.delete, size: 18),
                                color: Colors.red,
                                onPressed: _isSaving ? null : () => _deleteIssuedEntry(index, entry),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String? _quantityValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Required';
    }
    final qty = int.tryParse(value);
    if (qty == null) {
      return 'Invalid number';
    }
    if (qty < 0) {
      return 'Cannot be negative';
    }
    return null;
  }

  Widget _buildCompactTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.grey[600], size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        labelStyle: const TextStyle(fontSize: 13),
        hintStyle: TextStyle(fontSize: 12, color: Colors.grey[500]),
        errorStyle: const TextStyle(fontSize: 11),
      ),
    );
  }

  Widget _buildCompactDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedUom,
      isExpanded: true,
      style: const TextStyle(fontSize: 14, color: Colors.black),
      decoration: InputDecoration(
        labelText: 'UOM',
        prefixIcon: Icon(Icons.straighten, color: Colors.grey[600], size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[600]!, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        labelStyle: const TextStyle(fontSize: 13),
      ),
      items: _uomOptions.map((String uom) {
        return DropdownMenuItem<String>(
          value: uom,
          child: Text(uom, style: const TextStyle(fontSize: 13)),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null && mounted) {
          setState(() {
            _selectedUom = newValue;
          });
        }
      },
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      )
    );
  }

  Widget _buildInfoDisplay({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      )
    );
  }
}