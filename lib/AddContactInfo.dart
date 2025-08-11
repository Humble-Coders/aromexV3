import 'package:aromex/util.dart';
import 'package:aromex/widgets/custom_text_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddContactInfo extends StatefulWidget {
  const AddContactInfo({super.key});

  @override
  State<AddContactInfo> createState() => _AddContactInfoState();
}

class _AddContactInfoState extends State<AddContactInfo> {
  // Controllers
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController addressLine1Controller = TextEditingController();
  final TextEditingController addressLine2Controller = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController postalCodeController = TextEditingController();
  final TextEditingController countryController = TextEditingController();

  // Errors
  String? phoneError;
  String? addressLine1Error;
  String? cityError;
  String? stateError;
  String? postalCodeError;
  String? countryError;

  // Loading states
  bool isLoading = true;
  bool isSaving = false;

  // Existing data
  DocumentSnapshot? existingDoc;
  String? existingDocId;

  @override
  void initState() {
    super.initState();
    loadExistingAddress();
  }

  @override
  void dispose() {
    phoneController.dispose();
    addressLine1Controller.dispose();
    addressLine2Controller.dispose();
    cityController.dispose();
    stateController.dispose();
    postalCodeController.dispose();
    countryController.dispose();
    super.dispose();
  }

  Future<void> loadExistingAddress() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load admin address from Firebase
      final docRef = FirebaseFirestore.instance
          .collection('AdminInfo')
          .doc('admin');

      final doc = await docRef.get();

      if (doc.exists) {
        existingDoc = doc;
        existingDocId = doc.id;
        final data = doc.data() as Map<String, dynamic>;

        // Populate controllers with existing data
        phoneController.text = data['phone'] ?? '';

        if (data['address'] != null) {
          final address = data['address'] as Map<String, dynamic>;
          addressLine1Controller.text = address['line1'] ?? '';
          addressLine2Controller.text = address['line2'] ?? '';
          cityController.text = address['city'] ?? '';
          stateController.text = address['state'] ?? '';
          postalCodeController.text = address['postalCode'] ?? '';
          countryController.text = address['country'] ?? '';
        }
      }
    } catch (e) {
      print('Error loading existing address: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error loading existing address: $e"),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Loading address information...',
                style: textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back button
            IconButton(
              icon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back),
                  const SizedBox(width: 8),
                  Text(
                    'Back to home',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              onPressed: () => Navigator.pop(context),
            ),

            Card(
              color: colorScheme.secondary,
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(36.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            existingDoc != null
                                ? "Update Admin Address & Phone"
                                : "Add Admin Address & Phone",
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Spacer(),
                          if (existingDoc != null)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Address Found',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        "This information will be used on all generated bills and invoices",
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.7),
                          fontStyle: FontStyle.italic,
                        ),
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
                            // Phone Number Section
                            Text(
                              "Contact Information",
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    title: "Phone Number",
                                    textController: phoneController,
                                    description: "Enter phone number",
                                    error: phoneError,
                                    onChanged: (val) {
                                      setState(() {
                                        if (validatePhone(val)) {
                                          phoneError = null;
                                        } else {
                                          phoneError = "Invalid phone number";
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Address Section
                            Text(
                              "Address Information",
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Address Line 1 & 2
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    title: "Address Line 1",
                                    textController: addressLine1Controller,
                                    description: "Enter street address",
                                    error: addressLine1Error,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val.trim().isNotEmpty) {
                                          addressLine1Error = null;
                                        } else {
                                          addressLine1Error =
                                              "Address line 1 is required";
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CustomTextField(
                                    title: "Address Line 2",
                                    textController: addressLine2Controller,
                                    description: "Enter suite, floor, etc.",
                                    isMandatory: false,
                                    onChanged: (_) {
                                      setState(() {});
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // City & State
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    title: "City",
                                    textController: cityController,
                                    description: "Enter city",
                                    error: cityError,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val.trim().isNotEmpty) {
                                          cityError = null;
                                        } else {
                                          cityError = "City is required";
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CustomTextField(
                                    title: "State/Province",
                                    textController: stateController,
                                    description: "Enter state or province",
                                    error: stateError,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val.trim().isNotEmpty) {
                                          stateError = null;
                                        } else {
                                          stateError =
                                              "State/Province is required";
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Postal Code & Country
                            Row(
                              children: [
                                Expanded(
                                  child: CustomTextField(
                                    title: "Postal Code",
                                    textController: postalCodeController,
                                    description: "Enter postal/zip code",
                                    error: postalCodeError,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val.trim().isNotEmpty) {
                                          postalCodeError = null;
                                        } else {
                                          postalCodeError =
                                              "Postal code is required";
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CustomTextField(
                                    title: "Country",
                                    textController: countryController,
                                    description: "Enter country",
                                    error: countryError,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val.trim().isNotEmpty) {
                                          countryError = null;
                                        } else {
                                          countryError = "Country is required";
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 32),

                            // Action Buttons
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
                                    style: TextStyle(
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed:
                                      !validate() || isSaving
                                          ? null
                                          : () async {
                                            await saveAdminInfo();
                                          },
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 28,
                                      vertical: 16,
                                    ),
                                    backgroundColor: colorScheme.primary,
                                  ),
                                  child:
                                      isSaving
                                          ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: colorScheme.onPrimary,
                                            ),
                                          )
                                          : Text(
                                            existingDoc != null
                                                ? "Update Info"
                                                : "Save Info",
                                            style: TextStyle(
                                              color: colorScheme.onPrimary,
                                            ),
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
            ),
          ],
        ),
      ),
    );
  }

  bool validate() {
    return phoneController.text.trim().isNotEmpty &&
        addressLine1Controller.text.trim().isNotEmpty &&
        cityController.text.trim().isNotEmpty &&
        stateController.text.trim().isNotEmpty &&
        postalCodeController.text.trim().isNotEmpty &&
        countryController.text.trim().isNotEmpty &&
        phoneError == null &&
        addressLine1Error == null &&
        cityError == null &&
        stateError == null &&
        postalCodeError == null &&
        countryError == null;
  }

  Future<void> saveAdminInfo() async {
    if (!validate()) return;

    setState(() {
      isSaving = true;
    });

    try {
      final adminData = {
        'phone': phoneController.text.trim(),
        'address': {
          'line1': addressLine1Controller.text.trim(),
          'line2':
              addressLine2Controller.text.trim().isNotEmpty
                  ? addressLine2Controller.text.trim()
                  : null,
          'city': cityController.text.trim(),
          'state': stateController.text.trim(),
          'postalCode': postalCodeController.text.trim(),
          'country': countryController.text.trim(),
        },
        'updatedAt': Timestamp.now(),
      };

      // Add createdAt only for new documents
      if (existingDoc == null) {
        adminData['createdAt'] = Timestamp.now();
      }

      // Use set with merge option to update existing doc or create new one
      await FirebaseFirestore.instance
          .collection('AdminInfo')
          .doc('admin')
          .set(adminData, SetOptions(merge: true));

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              existingDoc != null
                  ? "Admin information updated successfully"
                  : "Admin information saved successfully",
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }
}
