import 'package:aromex/models/balance_generic.dart';
import 'package:aromex/models/transaction.dart';
import 'package:aromex/pages/home/main.dart';
import 'package:aromex/util.dart';
import 'package:aromex/widgets/custom_text_field.dart';
import 'package:aromex/widgets/searchable_dropdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddExpense extends StatefulWidget {
  final Function(Pages) onPageChange;
  const AddExpense({super.key, required this.onPageChange});

  @override
  State<AddExpense> createState() => _AddExpenseState();
}

class _AddExpenseState extends State<AddExpense> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();
  String? selectedCategory;
  final TextEditingController dateController = TextEditingController();
  final TextEditingController notesController = TextEditingController();

  List<String>? categories;

  String? amountError;
  String? categoryError;
  String? dateError;
  String? notesError;

  @override
  void initState() {
    super.initState();
    getCategories();

    // Add listener to category controller to handle manual typing
    categoryController.addListener(_onCategoryTextChanged);
  }

  @override
  void dispose() {
    categoryController.removeListener(_onCategoryTextChanged);
    categoryController.dispose();
    amountController.dispose();
    dateController.dispose();
    notesController.dispose();
    super.dispose();
  }

  void _onCategoryTextChanged() {
    final currentText = categoryController.text;

    // If controller text is different from selected category
    if (currentText != selectedCategory) {
      // Check if the typed text exists in categories
      if (categories?.contains(currentText) == true) {
        // User typed an existing category name
        if (selectedCategory != currentText) {
          setState(() {
            selectedCategory = currentText;
          });
        }
      } else {
        // User is typing something new - clear selection if text is not empty
        if (currentText.isNotEmpty && selectedCategory != null) {
          setState(() {
            selectedCategory = null;
          });
        }
      }
    }
  }

  Future<void> getCategories() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection("Data")
              .doc("ExpenseCategories")
              .get();

      if (snapshot.exists) {
        categories = snapshot.get("categories")?.cast<String>();
      } else {
        // Create document if it doesn't exist
        await FirebaseFirestore.instance
            .collection("Data")
            .doc("ExpenseCategories")
            .set({"categories": []});
        categories = [];
      }
      setState(() {});
    } catch (e) {
      print("Error fetching categories: $e");
      categories = [];
      setState(() {});
    }
  }

  void createCategory(String item) async {
    print("🔥 Creating category: $item");

    // Validate item is not empty
    if (item.trim().isEmpty) {
      setState(() {
        categoryError = "Category name cannot be empty";
      });
      return;
    }

    // Check if category already exists
    if (categories?.contains(item) == true) {
      setState(() {
        selectedCategory = item;
        categoryController.text = item;
        categoryError = null;
      });
      print("✅ Category already exists, selected: $item");
      return;
    }

    setState(() {
      categoryController.text = "Creating category...";
      categoryError = null;
    });

    try {
      print("📤 Sending to Firebase...");

      // Get the document first to ensure it exists
      DocumentReference docRef = FirebaseFirestore.instance
          .collection("Data")
          .doc("ExpenseCategories");

      DocumentSnapshot doc = await docRef.get();

      if (!doc.exists) {
        // Create document if it doesn't exist
        await docRef.set({
          "categories": [item],
        });
        print("📄 Document created with category: $item");
      } else {
        // Update existing document
        await docRef.update({
          "categories": FieldValue.arrayUnion([item]),
        });
        print("📝 Document updated with category: $item");
      }

      // Success - update UI
      setState(() {
        if (categories == null) {
          categories = [item];
        } else {
          categories!.add(item);
        }
        selectedCategory = item;
        categoryController.text = item;
        categoryError = null;
      });

      print("✅ Category created successfully: $item");

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Category '$item' created successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (error) {
      print("❌ Error creating category: $error");

      setState(() {
        categoryError = "Failed to create category: ${error.toString()}";
        categoryController.text = "";
        selectedCategory = null;
      });

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to create category: ${error.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void clearCategorySelection() {
    setState(() {
      selectedCategory = null;
      categoryController.clear();
      categoryError = null;
    });
  }

  bool validate() {
    bool isValid = true;

    // Validate amount
    if (amountController.text.isEmpty) {
      setState(() {
        amountError = "Amount is required";
      });
      isValid = false;
    } else {
      try {
        double.parse(amountController.text);
        setState(() {
          amountError = null;
        });
      } catch (e) {
        setState(() {
          amountError = "Invalid amount";
        });
        isValid = false;
      }
    }

    // Validate category
    if (selectedCategory == null && categoryController.text.isEmpty) {
      setState(() {
        categoryError = "Category is required";
      });
      isValid = false;
    } else {
      setState(() {
        categoryError = null;
      });
    }

    // Validate date
    if (dateController.text.isEmpty) {
      setState(() {
        dateError = "Date is required";
      });
      isValid = false;
    } else {
      setState(() {
        dateError = null;
      });
    }

    return isValid;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      color: colorScheme.secondary,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(36.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    "Add Expense",
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onPageChange(Pages.expenseRecord);
                    },
                    child: Text("View Expense Record"),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.secondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.onSurfaceVariant.withAlpha(50),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            title: "Amount",
                            error: amountError,
                            textController: amountController,
                            description: "Enter expense amount",
                            onChanged: (val) {
                              setState(() {
                                if (val.isEmpty) {
                                  amountError = "Amount is required";
                                } else {
                                  try {
                                    double.parse(val);
                                    amountError = null;
                                  } catch (e) {
                                    amountError = "Invalid amount";
                                  }
                                }
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: SearchableDropdown<String>(
                                      title: "Category",
                                      description:
                                          "Select or add a new category",
                                      controller: categoryController,
                                      items: categories,
                                      onChanged: (item) {
                                        print(
                                          "🔄 onChanged called with: $item",
                                        );
                                        setState(() {
                                          selectedCategory = item;
                                          categoryError = null;
                                        });
                                      },
                                      selectedItem: selectedCategory,
                                      getLabel: (item) => item,
                                      onClear: () {
                                        print("🧹 onClear called");
                                        clearCategorySelection();
                                      },
                                      allowAddingNew: true,
                                      onNewItemSelected: (item) {
                                        print(
                                          "✨ onNewItemSelected called with: $item",
                                        );
                                        createCategory(item);
                                      },
                                      defaultConstructor: () => "",
                                    ),
                                  ),

                                  // Add clear button
                                ],
                              ),
                              // Show selected category

                              // Show error
                              if (categoryError != null)
                                Container(
                                  margin: EdgeInsets.only(top: 4),
                                  child: Text(
                                    categoryError!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.error,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CustomTextField(
                            title: "Date",
                            error: dateError,
                            isReadOnly: true,
                            textController: dateController,
                            description: "Enter expense date",
                            suffixIcon: const Icon(Icons.calendar_today),
                            onChanged: (val) {},
                            onTap: () async {
                              DateTime? selectedDate = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (selectedDate != null) {
                                dateController.text = formatDate(selectedDate);
                                setState(() {
                                  dateError = null;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            title: "Notes/Comments",
                            textController: notesController,
                            description: "Enter notes/comments",
                            onChanged: (_) {
                              setState(() {});
                            },
                            isMandatory: false,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            padding: EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 16,
                            ),
                          ),
                          child: Text(
                            "Cancel",
                            style: TextStyle(color: colorScheme.onPrimary),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            if (!validate()) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Please fill all required fields",
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // If user typed a new category but didn't add it
                            if (selectedCategory == null &&
                                categoryController.text.isNotEmpty) {
                              // Ask user if they want to add this as new category
                              bool? shouldAdd = await showDialog<bool>(
                                context: context,
                                builder:
                                    (context) => AlertDialog(
                                      title: Text("Add New Category?"),
                                      content: Text(
                                        "Do you want to add '${categoryController.text}' as a new category?",
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, false),
                                          child: Text("Cancel"),
                                        ),
                                        TextButton(
                                          onPressed:
                                              () =>
                                                  Navigator.pop(context, true),
                                          child: Text("Add"),
                                        ),
                                      ],
                                    ),
                              );

                              if (shouldAdd == true) {
                                createCategory(categoryController.text);
                                return; // Wait for category creation to complete
                              } else {
                                return;
                              }
                            }

                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) {
                                return Center(
                                  child: CircularProgressIndicator(),
                                );
                              },
                            );

                            try {
                              // Add expense to firebase
                              Balance? balance = await Balance.fromType(
                                BalanceType.expenseRecord,
                              );

                              String categoryToUse =
                                  selectedCategory ?? categoryController.text;

                              await balance.addAmount(
                                double.parse(amountController.text),
                                category: categoryToUse,
                                expenseNote: notesController.text,
                                transactionType: TransactionType.self,
                              );

                              Navigator.pop(context); // Close loading dialog
                              Navigator.pop(
                                context,
                              ); // Close add expense dialog

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Expense added successfully"),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              Navigator.pop(context); // Close loading dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Failed to add expense: ${e.toString()}",
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 16,
                            ),
                            backgroundColor: colorScheme.primary,
                          ),
                          child: Text(
                            "Add Expense",
                            style: TextStyle(color: colorScheme.onPrimary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
