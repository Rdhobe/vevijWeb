import 'dart:async';
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

  // Debounce timer for auto-save
  Timer? _debounceTimer;

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

    // Add listeners for auto-save on text field changes
    _materialNameController.addListener(_onFieldChanged);
    _requiredQtyController.addListener(_onFieldChanged);
    _balIssueQtyController.addListener(_onFieldChanged);
    _usedQtyController.addListener(_onFieldChanged);

    // Use post-frame callback to ensure widget is mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInventoryItem();
    });
  }

  void _onFieldChanged() {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Start new timer - auto-save after 15 seconds of no changes
    _debounceTimer = Timer(const Duration(milliseconds: 15000), () {
      _autoSave();
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
    _debounceTimer?.cancel();
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
        _receivedEntries =
            List<Map<String, dynamic>>.from(
              _originalData['receivedEntries'] as List,
            ).map((entry) {
              return {
                'challanNo': entry['challanNo']?.toString() ?? '',
                'date': entry['date']?.toString() ?? '',
                'qty': _safeParseInt(entry['qty']),
              };
            }).toList();

        _issuedEntries =
            List<Map<String, dynamic>>.from(
              _originalData['issuedEntries'] as List,
            ).map((entry) {
              return {
                'challanNo': entry['challanNo']?.toString() ?? '',
                'date': entry['date']?.toString() ?? '',
                'qty': _safeParseInt(entry['qty']),
              };
            }).toList();

        if (mounted) {
          setState(() {
            _materialNameController.text =
                _originalData['materialName'] as String;
            _requiredQtyController.text = _originalData['requiredQty']
                .toString();
            _balIssueQtyController.text = _originalData['balIssueQty']
                .toString();
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

  List<String> _getChanges() {
    List<String> changes = [];

    final originalName = _originalData['materialName']?.toString() ?? '';
    final newName = _materialNameController.text.trim();
    if (originalName != newName) {
      changes.add('Material name: "$originalName" → "$newName"');
    }

    final newRequiredQty = int.tryParse(_requiredQtyController.text) ?? 0;
    final originalRequiredQty = _safeParseInt(_originalData['requiredQty']);
    if (originalRequiredQty != newRequiredQty) {
      changes.add('Required qty: $originalRequiredQty → $newRequiredQty');
    }

    // Calculate current totals from entries
    final currentTotalReceived = _receivedEntries.fold<int>(0, (acc, entry) {
      return acc + (entry['qty'] as int? ?? 0);
    });
    final originalTotalReceived = _safeParseInt(
      _originalData['totalReceivedQty'],
    );
    if (originalTotalReceived != currentTotalReceived) {
      changes.add(
        'Total received qty: $originalTotalReceived → $currentTotalReceived',
      );
    }

    // Calculate current totals from issued entries
    final currentTotalIssued = _issuedEntries.fold<int>(0, (acc, entry) {
      return acc + (entry['qty'] as int? ?? 0);
    });
    final originalTotalIssued = _safeParseInt(_originalData['totalIssuedQty']);
    if (originalTotalIssued != currentTotalIssued) {
      changes.add(
        'Total issued qty: $originalTotalIssued → $currentTotalIssued',
      );
    }

    final newBalIssueQty = int.tryParse(_balIssueQtyController.text) ?? 0;
    final originalBalIssueQty = _safeParseInt(_originalData['balIssueQty']);
    if (originalBalIssueQty != newBalIssueQty) {
      changes.add('Balance issue qty: $originalBalIssueQty → $newBalIssueQty');
    }

    final newUsedQty = int.tryParse(_usedQtyController.text) ?? 0;
    final originalUsedQty = _safeParseInt(_originalData['usedQty']);
    if (originalUsedQty != newUsedQty) {
      changes.add('Used qty: $originalUsedQty → $newUsedQty');
    }

    final originalUom = _originalData['uom']?.toString() ?? 'PCS';
    if (originalUom != _selectedUom) {
      changes.add('UOM: "$originalUom" → "$_selectedUom"');
    }

    // Check for received entries changes
    final originalReceived = List<Map<String, dynamic>>.from(
      (_originalData['receivedEntries'] ?? []) as List,
    );
    if (originalReceived.length != _receivedEntries.length) {
      changes.add(
        'Received entries count changed: ${originalReceived.length} → ${_receivedEntries.length}',
      );
    }

    // Check for issued entries changes
    final originalIssued = List<Map<String, dynamic>>.from(
      (_originalData['issuedEntries'] ?? []) as List,
    );
    if (originalIssued.length != _issuedEntries.length) {
      changes.add(
        'Issued entries count changed: ${originalIssued.length} → ${_issuedEntries.length}',
      );
    }

    return changes;
  }

  Future<void> _autoSave() async {
    // Check if form is ready and mounted
    if (!_formReady || !mounted) {
      return;
    }

    // Check if form key exists
    if (_formKey.currentState == null) {
      return;
    }

    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Clean entries with null quantities before calculations
    _receivedEntries.removeWhere((e) => e['qty'] == null);
    _issuedEntries.removeWhere((e) => e['qty'] == null);

    // Get changes for history
    final changes = _getChanges();

    if (!mounted) return;

    setState(() => _isSaving = true);

    try {
      // Parse input values safely
      final requiredQty =
          int.tryParse(_requiredQtyController.text) ??
          _safeParseInt(_originalData['requiredQty']);

      final usedQty =
          int.tryParse(_usedQtyController.text) ??
          _safeParseInt(_originalData['usedQty']);

      final balIssueQty =
          int.tryParse(_balIssueQtyController.text) ??
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

      // Create edit history entry
      final editEntry = {
        'editedBy': FirebaseAuth.instance.currentUser?.email ?? 'Unknown',
        'editDate':
            '${DateTime.now().day}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year}',
        'timestamp': Timestamp.now(),
        'changes': changes,
      };

      if (_reasonController.text.trim().isNotEmpty) {
        editEntry['reason'] = _reasonController.text.trim();
      }

      final docRef = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.projectId)
          .collection('inventory')
          .doc(widget.itemId);

      // Get current document to check structure
      final snapshot = await docRef.get();

      // Prepare data for update
      final Map<String, dynamic> updateData = {
        ...updatedData,
        'editHistory': FieldValue.arrayUnion([editEntry]),
      };

      try {
        if (!snapshot.exists) {
          // Document doesn't exist - create it with all fields
          await docRef.set({
            ...updateData,
            'createdAt': Timestamp.now(),
            'projectId': widget.projectId,
          });
        } else {
          // Document exists - update it
          await docRef.update(updateData);
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

  void _addReceivedEntry() {
    _showEntryDialog(
      title: 'Add Received Entry',
      isReceived: true,
      onSave: (challanNo, date, qty) async {
        if (mounted) {
          setState(() {
            _receivedEntries.add({
              'challanNo': challanNo,
              'date': date,
              'qty': qty,
            });
          });
          // Auto-save after adding entry
          await _autoSave();
        }
      },
    );
  }

  void _editReceivedEntry(int index) {
    if (index < 0 || index >= _receivedEntries.length) return;

    final entry = _receivedEntries[index];
    _showEntryDialog(
      title: 'Edit Received Entry',
      initialChallanNo: entry['challanNo']?.toString() ?? '',
      initialDate: entry['date']?.toString() ?? '',
      initialQty: entry['qty'] as int? ?? 0,
      isReceived: true,
      editingIndex: index,
      onSave: (challanNo, date, qty) async {
        if (mounted) {
          setState(() {
            _receivedEntries[index] = {
              'challanNo': challanNo,
              'date': date,
              'qty': qty,
            };
          });
          // Auto-save after editing entry
          await _autoSave();
        }
      },
    );
  }

  void _deleteReceivedEntry(int index) {
    if (index < 0 || index >= _receivedEntries.length) return;

    // Show confirmation dialog before deleting
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Received Entry'),
        content: const Text(
          'Are you sure you want to delete this received entry? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (mounted) {
                setState(() {
                  _receivedEntries.removeAt(index);
                });
                // Auto-save after deleting entry
                await _autoSave();
              }
              Navigator.of(context).pop();
              _showSnackBar('Received entry deleted', Colors.orange);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _addIssuedEntry() {
    _showEntryDialog(
      title: 'Add Issued Entry',
      isReceived: false,
      onSave: (challanNo, date, qty) async {
        if (mounted) {
          setState(() {
            _issuedEntries.add({
              'challanNo': challanNo,
              'date': date,
              'qty': qty,
            });
          });
          // Auto-save after adding entry
          await _autoSave();
        }
      },
    );
  }

  void _editIssuedEntry(int index) {
    if (index < 0 || index >= _issuedEntries.length) return;

    final entry = _issuedEntries[index];
    _showEntryDialog(
      title: 'Edit Issued Entry',
      initialChallanNo: entry['challanNo']?.toString() ?? '',
      initialDate: entry['date']?.toString() ?? '',
      initialQty: entry['qty'] as int? ?? 0,
      isReceived: false,
      editingIndex: index,
      onSave: (challanNo, date, qty) async {
        if (mounted) {
          setState(() {
            _issuedEntries[index] = {
              'challanNo': challanNo,
              'date': date,
              'qty': qty,
            };
          });
          // Auto-save after editing entry
          await _autoSave();
        }
      },
    );
  }

  void _deleteIssuedEntry(int index) {
    if (index < 0 || index >= _issuedEntries.length) return;

    // Show confirmation dialog before deleting
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Issued Entry'),
        content: const Text(
          'Are you sure you want to delete this issued entry? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (mounted) {
                setState(() {
                  _issuedEntries.removeAt(index);
                });
                // Auto-save after deleting entry
                await _autoSave();
              }
              Navigator.of(context).pop();
              _showSnackBar('Issued entry deleted', Colors.orange);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEntryDialog({
    required String title,
    String initialChallanNo = '',
    String initialDate = '',
    int initialQty = 0,
    required Function(String, String, int) onSave,
    bool isReceived = true,
    int? editingIndex,
  }) {
    final challanController = TextEditingController(text: initialChallanNo);
    final dateController = TextEditingController(text: initialDate);
    final qtyController = TextEditingController(text: initialQty.toString());

    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: challanController,
                decoration: const InputDecoration(
                  labelText: 'Challan No',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: 'Date (DD.MM.YYYY)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
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
                  helperText: _getQuantityHelperText(isReceived),
                  helperMaxLines: 2,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    errorMessage = _validateQuantity(
                      value,
                      isReceived,
                      editingIndex,
                    );
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
              onPressed: () => Navigator.of(context).pop(),
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
                        onSave(challanNo, date, qty);
                        Navigator.of(context).pop();
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateQuantity(String value, bool isReceived, int? editingIndex) {
    final qty = int.tryParse(value);
    if (qty == null || qty <= 0) {
      return qty == null
          ? 'Please enter a valid number'
          : 'Quantity must be greater than 0';
    }

    final requiredQty =
        int.tryParse(_requiredQtyController.text) ??
        _safeParseInt(_originalData['requiredQty']);

    if (isReceived) {
      // Calculate current total received (excluding the entry being edited)
      int currentTotalReceived = 0;
      for (int i = 0; i < _receivedEntries.length; i++) {
        if (editingIndex == null || i != editingIndex) {
          final entry = _receivedEntries[i];
          final entryQty = entry['qty'] as int?;
          if (entryQty != null) {
            currentTotalReceived += entryQty;
          }
        }
      }

      final newTotalReceived = currentTotalReceived + qty;

      if (newTotalReceived > requiredQty) {
        return 'Cannot exceed required quantity ($requiredQty)\nCurrent total would be: $newTotalReceived';
      }
    } else {
      // For issued entries - validate against available quantity
      final currentTotalReceived = _receivedEntries.fold<int>(0, (acc, entry) {
        final entryQty = entry['qty'] as int?;
        return entryQty != null ? acc + entryQty : acc;
      });

      final currentUsedQty =
          int.tryParse(_usedQtyController.text) ??
          _safeParseInt(_originalData['usedQty']);

      // Calculate current total issued (excluding the entry being edited)
      int currentTotalIssued = 0;
      for (int i = 0; i < _issuedEntries.length; i++) {
        if (editingIndex == null || i != editingIndex) {
          final entry = _issuedEntries[i];
          final entryQty = entry['qty'] as int?;
          if (entryQty != null) {
            currentTotalIssued += entryQty;
          }
        }
      }

      final availableQty =
          currentTotalReceived - currentTotalIssued - currentUsedQty;

      if (qty > availableQty) {
        return 'Cannot issue more than available quantity ($availableQty)\nReceived: $currentTotalReceived, Used: $currentUsedQty, Already Issued: $currentTotalIssued';
      }
    }

    return null;
  }

  String _getQuantityHelperText(bool isReceived) {
    if (isReceived) {
      final requiredQty =
          int.tryParse(_requiredQtyController.text) ??
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

      final currentUsedQty =
          int.tryParse(_usedQtyController.text) ??
          _safeParseInt(_originalData['usedQty']);

      final currentTotalIssued = _issuedEntries.fold<int>(0, (acc, entry) {
        final entryQty = entry['qty'] as int?;
        return entryQty != null ? acc + entryQty : acc;
      });

      final available =
          currentTotalReceived - currentTotalIssued - currentUsedQty;

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
        elevation: 0.5,
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        actions: [
          // Auto-save indicator
          if (_isSaving)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.blue[600]!,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Saving...',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
        bottom: _isLoading
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(48),
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

    final usedQty =
        int.tryParse(_usedQtyController.text) ??
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
                                    color: balanceQty < 0
                                        ? Colors.red
                                        : Colors.blue,
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
                                    color: balanceQty < 0
                                        ? Colors.red
                                        : Colors.blue,
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

                          // Reason field
                          _buildCompactTextField(
                            controller: _reasonController,
                            label: 'Reason for Changes (Optional)',
                            icon: Icons.note_alt_outlined,
                            maxLines: 2,
                            hint: 'Brief reason for the changes...',
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
                                  color: Colors.blueAccent,
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
                    onPressed: _addReceivedEntry,
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
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _editReceivedEntry(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                color: Colors.red,
                                onPressed: () => _deleteReceivedEntry(index),
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
                    onPressed: _addIssuedEntry,
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
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _editIssuedEntry(index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 18),
                                color: Colors.red,
                                onPressed: () => _deleteIssuedEntry(index),
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
          // Auto-save when UOM changes
          _onFieldChanged();
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
      ),
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
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
      ),
    );
  }
}
