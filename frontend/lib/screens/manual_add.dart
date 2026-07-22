import 'package:flutter/material.dart';
import '../services/bill_service.dart';
import '../components/header.dart';
import '../components/initial_avatar.dart';
import 'expense_summary.dart';
import '../themes/app_theme.dart';

class ManuallyAddPage extends StatefulWidget {
  final String groupId;
  final List<Map<String, String>> members;

  const ManuallyAddPage({
    super.key,
    required this.groupId,
    required this.members,
  });

  @override
  State<ManuallyAddPage> createState() => _ManuallyAddPageState();
}

class _ManuallyAddPageState extends State<ManuallyAddPage> {
  String? _selectedPaidBy;
  String _splitMethod = 'Equally'; // 'Equally' or 'By Items'
  final TextEditingController _totalAmountController = TextEditingController();
  final TextEditingController _billNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  Map<String, bool> _selectedMembers = {};
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    // Initialize all members as selected by default for equally split
    for (var member in widget.members) {
      _selectedMembers[member['email']!] = true;
    }
    // Set first member as default payer
    if (widget.members.isNotEmpty) {
      _selectedPaidBy = widget.members[0]['email'];
    }
  }

  void _calculateEqualSplit() {
    if (_totalAmountController.text.isEmpty) return;

    try {
      _totalAmount = double.parse(_totalAmountController.text);
      final selectedCount = _selectedMembers.values.where((v) => v).length;

      if (selectedCount > 0) {
        setState(() {});
      }
    } catch (e) {
      // Invalid amount
    }
  }

  void _addItem() {
    final TextEditingController itemNameController = TextEditingController();
    final TextEditingController itemQuantityController = TextEditingController();
    final TextEditingController itemPriceController = TextEditingController();
    Map<String, bool> selectedMembers = {};
    Map<String, TextEditingController> memberQuantityControllers = {};
    String distributionMethod = 'Equally'; // 'Equally' or 'By Quantity'

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final isDarkDialog = Theme.of(context).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: EdgeInsets.fromLTRB(20, 12, 20, 0),
              title: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.add_shopping_cart, color: Theme.of(context).primaryColor, size: 20),
                  ),
                  SizedBox(width: 12),
                  Text('Add Item', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 4),
                    _dialogLabel('Item Name'),
                    SizedBox(height: 6),
                    TextField(
                      controller: itemNameController,
                      decoration: InputDecoration(
                        hintText: 'e.g., Pizza',
                        prefixIcon: Icon(Icons.restaurant_menu, size: 18),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    SizedBox(height: 14),

                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _dialogLabel('Quantity'),
                        SizedBox(height: 6),
                        TextField(
                          controller: itemQuantityController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '1',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ])),
                      SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _dialogLabel('Unit Price'),
                        SizedBox(height: 6),
                        TextField(
                          controller: itemPriceController,
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixText: '₹ ',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                      ])),
                    ]),
                    SizedBox(height: 14),

                    _dialogLabel('Distribution Method'),
                    SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: isDarkDialog
                            ? Theme.of(context).primaryColor.withOpacity(0.08)
                            : Theme.of(context).primaryColor.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.15)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setStateDialog(() {
                                  distributionMethod = 'Equally';
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: distributionMethod == 'Equally'
                                      ? Theme.of(context).primaryColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Equally',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: distributionMethod == 'Equally'
                                        ? Colors.white
                                        : Theme.of(context).textTheme.bodyMedium?.color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setStateDialog(() {
                                  distributionMethod = 'By Quantity';
                                });
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: distributionMethod == 'By Quantity'
                                      ? Theme.of(context).primaryColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'By Quantity',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: distributionMethod == 'By Quantity'
                                        ? Colors.white
                                        : Theme.of(context).textTheme.bodyMedium?.color,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 14),

                    _dialogLabel('Taken By'),
                    SizedBox(height: 6),

                    // Equally Distribution Mode
                    if (distributionMethod == 'Equally') ...[
                      Container(
                        constraints: BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          border: Border.all(color: Theme.of(context).dividerColor),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: widget.members.map((member) {
                              final email = member['email']!;
                              final isSelected = selectedMembers[email] ?? false;
                              return CheckboxListTile(
                                value: isSelected,
                                activeColor: Theme.of(context).primaryColor,
                                onChanged: (value) => setStateDialog(() { selectedMembers[email] = value ?? false; }),
                                title: Row(children: [
                                  InitialAvatar(name: member['name']!, radius: 14),
                                  SizedBox(width: 10),
                                  Expanded(child: Text(member['name']!, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w500))),
                                ]),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10),
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                    
                    // By Quantity Distribution Mode
                    if (distributionMethod == 'By Quantity') ...[
                      Container(
                        constraints: BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            children: widget.members.map((member) {
                              final email = member['email']!;
                              final isSelected = selectedMembers[email] ?? false;
                              
                              // Initialize controller if not exists
                              if (!memberQuantityControllers.containsKey(email)) {
                                memberQuantityControllers[email] = TextEditingController();
                              }
                              
                              return Container(
                                padding: EdgeInsets.all(12),
                                margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected 
                                        ? Theme.of(context).primaryColor.withOpacity(0.5)
                                        : Colors.grey.shade200,
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                          onChanged: (value) {
                            setStateDialog(() {
                                          selectedMembers[email] = value ?? false;
                                          if (!isSelected) {
                                            memberQuantityControllers[email]?.clear();
                                          }
                            });
                          },
                                      activeColor: Theme.of(context).primaryColor,
                                    ),
                                    InitialAvatar(name: member['name']!, radius: 16),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        member['name']!,
                                        style: TextStyle(fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Container(
                                      width: 80,
                                      child: TextField(
                                        controller: memberQuantityControllers[email],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        enabled: isSelected,
                                        decoration: InputDecoration(
                                          hintText: '0',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: isSelected 
                                                  ? Theme.of(context).primaryColor.withOpacity(0.3)
                                                  : Colors.grey.shade300,
                                            ),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          isDense: true,
                                        ),
                                        onChanged: (value) {
                                          setStateDialog(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final totalQty = int.tryParse(itemQuantityController.text) ?? 0;
                                final selectedCount = selectedMembers.values.where((v) => v).length;
                                
                                if (selectedCount > 0 && totalQty > 0) {
                                  final equalQty = totalQty ~/ selectedCount;
                                  final remainder = totalQty % selectedCount;
                                  
                                  setStateDialog(() {
                                    int distributed = 0;
                                    for (final entry in selectedMembers.entries) {
                                      if (entry.value) {
                                        final email = entry.key;
                                        if (!memberQuantityControllers.containsKey(email)) {
                                          memberQuantityControllers[email] = TextEditingController();
                                        }
                                        
                                        int qty = equalQty;
                                        if (distributed < remainder) {
                                          qty += 1;
                                        }
                                        
                                        memberQuantityControllers[email]!.text = qty.toString();
                                        distributed++;
                                      }
                                    }
                                  });
                                }
                              },
                              icon: Icon(Icons.share, size: 16),
                              label: Text('Distribute Evenly'),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                side: BorderSide(color: Colors.grey.shade400),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setStateDialog(() {
                                  for (final controller in memberQuantityControllers.values) {
                                    controller.clear();
                                  }
                                });
                              },
                              icon: Icon(Icons.clear, size: 16),
                              label: Text('Clear All'),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                side: BorderSide(color: Colors.grey.shade400),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actionsPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                SizedBox(width: 4),
                ElevatedButton(
                  onPressed: () {
                    if (itemNameController.text.isEmpty ||
                        itemQuantityController.text.isEmpty ||
                        itemPriceController.text.isEmpty ||
                        selectedMembers.values.every((v) => !v)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please fill all fields and select at least one member'),
                          backgroundColor: AppColors.warning,
                        ),
                      );
                      return;
                    }

                    try {
                      final price = double.parse(itemPriceController.text);
                      final totalQuantity = int.parse(itemQuantityController.text);
                      
                      // Get selected member data
                      final selectedMemberData = widget.members
                          .where((member) => selectedMembers[member['email']!] == true)
                          .toList();

                      Map<String, int> memberQuantities = {};
                      
                      if (distributionMethod == 'By Quantity') {
                        // Validate member quantities for By Quantity mode
                        int totalMemberQuantities = 0;
                        
                        for (final entry in selectedMembers.entries) {
                          if (entry.value) {
                            final email = entry.key;
                            final quantityText = memberQuantityControllers[email]?.text ?? '0';
                            final memberQuantity = int.tryParse(quantityText) ?? 0;
                            
                            if (memberQuantity < 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Member quantities cannot be negative'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                              return;
                            }
                            
                            memberQuantities[email] = memberQuantity;
                            totalMemberQuantities += memberQuantity;
                          }
                        }
                        
                        // Check if total member quantities match item quantity
                        if (totalMemberQuantities != totalQuantity) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Total member quantities ($totalMemberQuantities) must equal item quantity ($totalQuantity)'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                          return;
                        }
                      } else {
                        // For Equally mode, distribute quantity equally among selected members
                        final selectedCount = selectedMembers.values.where((v) => v).length;
                        if (selectedCount > 0) {
                          final equalQty = totalQuantity ~/ selectedCount;
                          final remainder = totalQuantity % selectedCount;
                          int distributed = 0;
                          
                          for (final entry in selectedMembers.entries) {
                            if (entry.value) {
                              int qty = equalQty;
                              if (distributed < remainder) {
                                qty += 1;
                              }
                              memberQuantities[entry.key] = qty;
                              distributed++;
                            }
                          }
                        }
                      }

                      setState(() {
                        _items.add({
                          'name': itemNameController.text,
                          'quantity': totalQuantity,
                          'price': price,
                          'distributionMethod': distributionMethod,
                          'takenBy': selectedMemberData.map((m) => m['email']!).toList(),
                          'takenByNames': selectedMemberData.map((m) => m['name']!).toList(),
                          'takenByAvatars': selectedMemberData.map((m) => m['avatar']!).toList(),
                          'memberQuantities': memberQuantities,
                        });

                        // Update total amount
                        _totalAmount = _items.fold(0.0, (sum, item) => sum + item['price']);
                        _totalAmountController.text = _totalAmount.toStringAsFixed(2);
                      });

                      Navigator.of(ctx).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Invalid price or quantity'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text('Add Item', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _dialogLabel(String label) => Text(
    label,
    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.1),
  );

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _totalAmount = _items.fold(0.0, (sum, item) => sum + item['price']);
      _totalAmountController.text = _items.isEmpty ? '' : _totalAmount.toStringAsFixed(2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;
    final isDark = theme.brightness == Brightness.dark;

    final selectedCount = _selectedMembers.values.where((v) => v).length;
    final splitAmount = (_totalAmount > 0 && selectedCount > 0)
        ? _totalAmount / selectedCount
        : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Header(
            title: 'Add Manually',
            heightFactor: 0.12,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16),
                Text('Bill Name', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                SizedBox(height: 8),
                TextField(
                  controller: _billNameController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Grocery Run',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                SizedBox(height: 14),
                Row(children: [
                  Text('Where / Description', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                  SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('optional', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: theme.primaryColor)),
                  ),
                ]),
                SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Pizza, Rent, Groceries',
                    prefixIcon: Icon(Icons.place_outlined, size: 18),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Paid By Section
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Paid By',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              SizedBox(height: 10),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  border: Border.all(
                                    color: theme.primaryColor.withOpacity(0.3),
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedPaidBy,
                                    isExpanded: true,
                                    icon: Icon(Icons.arrow_drop_down, color: theme.primaryColor),
                                    items: widget.members.map((member) {
                                      return DropdownMenuItem<String>(
                                        value: member['email'],
                                        child: Row(
                                          children: [
                                            InitialAvatar(name: member['name']!, radius: 16),
                                            SizedBox(width: 12),
                                            Flexible(
                                              child: Text(
                                                member['name']!,
                                                style: TextStyle(color: textColor),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (value) {
                                      setState(() {
                                        _selectedPaidBy = value;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 16),

                        // Split Method Section
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Split Method',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _splitMethod = 'Equally';
                                            _items.clear();
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: _splitMethod == 'Equally'
                                                ? theme.primaryColor
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Equally',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: _splitMethod == 'Equally'
                                                  ? Colors.white
                                                  : textColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _splitMethod = 'By Items';
                                            _totalAmountController.clear();
                                            _totalAmount = 0.0;
                                          });
                                        },
                                        child: Container(
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          decoration: BoxDecoration(
                                            color: _splitMethod == 'By Items'
                                                ? theme.primaryColor
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'By Items',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: _splitMethod == 'By Items'
                                                  ? Colors.white
                                                  : textColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 24),

                    // Total Amount Section
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _totalAmountController,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      readOnly: _splitMethod == 'By Items',
                      onChanged: (value) => _calculateEqualSplit(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText: '\$\$\$\$\$',
                        hintStyle: TextStyle(
                          color: textColor.withOpacity(0.3),
                          fontSize: 24,
                        ),
                        prefixText: '₹ ',
                        prefixStyle: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        filled: true,
                        fillColor: cardColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.primaryColor.withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: theme.primaryColor,
                            width: 2,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),

                    SizedBox(height: 28),

                    // By Items - Add Items Button
                    if (_splitMethod == 'By Items') ...[
                      OutlinedButton.icon(
                        onPressed: _addItem,
                        icon: Icon(Icons.add),
                        label: Text('Add Items'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.primaryColor,
                          side: BorderSide(color: theme.primaryColor, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          minimumSize: Size(double.infinity, 50),
                        ),
                      ),
                      SizedBox(height: 16),

                      // Display Added Items
                      if (_items.isNotEmpty) ...[
                        Text(
                          'Items',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 10),
                        ..._items.asMap().entries.map((entry) {
                          final index = entry.key;
                          final item = entry.value;
                          return Container(
                            margin: EdgeInsets.only(bottom: 10),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.primaryColor.withOpacity(0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'],
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                      ),
                                      Text(
                                            'Qty: ${item['quantity']} × ₹ ${item['price'].toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: textColor.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close, size: 20, color: AppColors.danger),
                                  onPressed: () => _removeItem(index),
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: (item['takenByNames'] as List<String>).asMap().entries.map((entry) {
                                    final memberIndex = entry.key;
                                    final memberName = entry.value;
                                    final memberAvatar = (item['takenByAvatars'] as List<String>)[memberIndex];
                                    final memberEmail = (item['takenBy'] as List<String>)[memberIndex];
                                    final memberQuantities = item['memberQuantities'] as Map<String, int>?;
                                    final memberQuantity = memberQuantities?[memberEmail] ?? 0;
                                    
                                    return Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: theme.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: theme.primaryColor.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InitialAvatar(name: memberName, radius: 12),
                                          SizedBox(width: 6),
                                          Text(
                                            memberName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: textColor,
                                            ),
                                          ),
                                          if (memberQuantity > 0) ...[
                                            SizedBox(width: 4),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: theme.primaryColor,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                '×$memberQuantity',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        SizedBox(height: 16),
                      ],
                    ],

                    // Members Section (Equally Split)
                    if (_splitMethod == 'Equally') ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Members',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              bool allSelected = _selectedMembers.values.every((v) => v);
                              setState(() {
                                for (var key in _selectedMembers.keys) {
                                  _selectedMembers[key] = !allSelected;
                                }
                              });
                            },
                            child: Text('Include All'),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),

                      ...widget.members.map((member) {
                        final email = member['email']!;
                        final isSelected = _selectedMembers[email] ?? false;

                        return Container(
                          margin: EdgeInsets.only(bottom: 10),
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? theme.primaryColor.withOpacity(0.5)
                                  : Colors.grey.withOpacity(0.3),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isSelected,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedMembers[email] = value ?? false;
                                  });
                                },
                                activeColor: theme.primaryColor,
                              ),
                              InitialAvatar(name: member['name']!, radius: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  member['name']!,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              Text(
                                isSelected ? '₹ ${splitAmount.toStringAsFixed(2)}' : '₹ 0',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],

                    SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: ElevatedButton(
          onPressed: () {
            if (_billNameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please enter a bill name'),
                  backgroundColor: AppColors.warning,
                ),
              );
              return;
            }
            if (_splitMethod == 'Equally') {
              // For equally split, add bill directly
              _addBillDirectly();
            } else {
              // For by items, navigate to expense summary
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExpenseSummaryPage(
                    groupId: widget.groupId,
                    members: widget.members,
                    items: _items,
                    totalAmount: _totalAmount,
                    paidBy: _selectedPaidBy,
                    billName: _billNameController.text.trim(),
                  ),
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          child: Text(
            _splitMethod == 'Equally' ? 'Add Bill' : 'Continue',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _addBillDirectly() {
    // Validate required fields
    if (_totalAmountController.text.isEmpty || _totalAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a valid total amount'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_selectedPaidBy == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select who paid for this expense'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final selectedCount = _selectedMembers.values.where((v) => v).length;
    if (selectedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one member to split with'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    if (_billNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a bill name'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final payerName = widget.members.firstWhere((m) => m['email'] == _selectedPaidBy)['name']!;
    final perPerson = (_totalAmount / selectedCount).toStringAsFixed(2);

    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: theme.cardColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: EdgeInsets.fromLTRB(20, 16, 20, 8),
          actionsPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(children: [
            Container(
              padding: EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [theme.primaryColor, AppColors.primaryDeep], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.receipt_long, color: Colors.white, size: 18),
            ),
            SizedBox(width: 12),
            Text('Confirm Expense', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? theme.primaryColor.withOpacity(0.08)
                    : AppColors.primaryLight.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.primaryColor.withOpacity(0.15)),
              ),
              child: Column(children: [
                _confirmRow(Icons.tag, 'Bill Name', _billNameController.text.trim(), theme),
                if (_descriptionController.text.trim().isNotEmpty) ...[
                  Divider(height: 16, thickness: 0.5),
                  _confirmRow(Icons.place_outlined, 'Description', _descriptionController.text.trim(), theme),
                ],
                Divider(height: 16, thickness: 0.5),
                _confirmRow(Icons.currency_rupee, 'Total Amount', '₹ ${_totalAmount.toStringAsFixed(2)}', theme, highlight: true),
                Divider(height: 16, thickness: 0.5),
                _confirmRow(Icons.people_outline, 'Split Among', '$selectedCount member${selectedCount > 1 ? 's' : ''}', theme),
                Divider(height: 16, thickness: 0.5),
                _confirmRow(Icons.person_outline, 'Per Person', '₹ $perPerson', theme),
                Divider(height: 16, thickness: 0.5),
                _confirmRow(Icons.credit_card, 'Paid By', payerName, theme),
              ]),
            ),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
            SizedBox(width: 4),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                _submitExpense();
              },
              icon: Icon(Icons.check, size: 16),
              label: Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _confirmRow(IconData icon, String label, String value, ThemeData theme, {bool highlight = false}) {
    return Row(children: [
      Icon(icon, size: 16, color: theme.primaryColor.withOpacity(0.7)),
      SizedBox(width: 10),
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: theme.textTheme.bodySmall?.color))),
      Text(value, style: TextStyle(
        fontSize: 13,
        fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
        color: highlight ? theme.primaryColor : theme.textTheme.bodyMedium?.color,
      )),
    ]);
  }

  void _submitExpense() {
    final rawBillName = _billNameController.text.trim();
    final description = _descriptionController.text.trim();
    final billName = description.isNotEmpty ? '$rawBillName — $description' : rawBillName;
    final totalAmount = _totalAmount;
    final splitMethod = 'equal';

    // Resolve payer userId from email
    String? payerEmail = _selectedPaidBy;
    String? payerId = payerEmail == null
        ? null
        : widget.members.firstWhere((m) => m['email'] == payerEmail, orElse: () => {'id': ''})['id'];

    // Selected member ids (those included in split)
    final selectedEmails = _selectedMembers.entries.where((e) => e.value).map((e) => e.key).toList();
    final selectedMembers = widget.members.where((m) => selectedEmails.contains(m['email'])).toList();
    final selectedIds = selectedMembers.map((m) => m['id']!).toList();

    // Build payments array: single payer with totalAmount (method optional)
    final payments = <Map<String, dynamic>>[];
    if (payerId != null && payerId.isNotEmpty) {
      payments.add({
        'user': payerId,
        'amount': totalAmount,
        // 'method': 'cash', // optionally set if you collect it in UI
      });
    }

    // Compute equal share and assignments to payer
    final int participantCount = selectedIds.length;
    final double perShare = participantCount > 0 ? (totalAmount / participantCount) : 0.0;
    final assignments = <Map<String, dynamic>>[];
    if (payerId != null && payerId.isNotEmpty) {
      for (final m in selectedMembers) {
        final userId = m['id']!;
        if (userId == payerId) continue; // skip payer self
        assignments.add({
          'from': userId,
          'to': payerId,
          'amount': double.parse(perShare.toStringAsFixed(2)),
        });
      }
    }

    // For equally split: send a single synthesized item; include assignedTo user ids
    final items = [
      {
        'name': billName.isNotEmpty ? billName : 'Manual Expense',
        'quantity': 1,
        'price': totalAmount,
        'assignedTo': selectedIds,
      }
    ];

    BillService.createManualExpense(
      groupId: widget.groupId,
      totalAmount: totalAmount,
      items: items,
      billName: billName.isNotEmpty ? billName : 'Manual Expense',
      splitMethod: splitMethod,
      payments: payments,
      assignments: assignments,
    ).then((res) {
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Expense added successfully!')),
              ],
            ),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to create expense'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }).catchError((e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.danger,
        ),
      );
    });
  }

  @override
  void dispose() {
    _totalAmountController.dispose();
    _billNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
