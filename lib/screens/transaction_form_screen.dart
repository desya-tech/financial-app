import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../providers/finance_provider.dart';
import '../models/transaction.dart';
import '../theme/app_theme.dart';

class _DraftTransaction {
  TextEditingController amountController;
  TextEditingController descriptionController;
  String? subCategory;

  _DraftTransaction({
    required this.amountController,
    required this.descriptionController,
    this.subCategory,
  });

  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
  }
}

class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({super.key});

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  List<_DraftTransaction> _drafts = [];

  bool _isProcessingOcr = false;
  XFile? _receiptImage;

  @override
  void initState() {
    super.initState();
    _drafts.add(_createEmptyDraft());
  }

  _DraftTransaction _createEmptyDraft() {
    return _DraftTransaction(
      amountController: TextEditingController(),
      descriptionController: TextEditingController(),
    );
  }

  @override
  void dispose() {
    for (var draft in _drafts) {
      draft.dispose();
    }
    super.dispose();
  }

  Future<void> _scanReceipt(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _receiptImage = pickedFile;
        _isProcessingOcr = true;
      });

      try {
        final provider = Provider.of<FinanceProvider>(context, listen: false);
        final availableSubCats = provider.getAvailableSubCategories();

        final data = await provider.ocrService.extractReceiptInfo(_receiptImage!, availableSubCats);

        setState(() {
          if (data['date'] != null) {
            _selectedDate = DateTime.tryParse(data['date']) ?? DateTime.now();
          }

          if (data['items'] != null && data['items'] is List) {
            for (var d in _drafts) { d.dispose(); }
            _drafts.clear();

            for (var item in data['items']) {
              final amountStr = item['amount']?.toString() ?? '';
              final descStr = item['description']?.toString() ?? '';
              String? catStr = item['subCategory'];
              if (catStr != null && catStr.isEmpty) catStr = null;

              _drafts.add(_DraftTransaction(
                amountController: TextEditingController(text: amountStr),
                descriptionController: TextEditingController(text: descStr),
                subCategory: catStr,
              ));
            }
          }

          if (_drafts.isEmpty) {
            _drafts.add(_createEmptyDraft());
          }
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nota berhasil dipindai!')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memindai: $e')),
        );
      } finally {
        setState(() {
          _isProcessingOcr = false;
        });
      }
    }
  }

  void _saveTransactions() async {
    if (_formKey.currentState!.validate()) {
      if (_drafts.isEmpty) return;

      final provider = Provider.of<FinanceProvider>(context, listen: false);

      for (var draft in _drafts) {
        if (draft.subCategory == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pastikan semua item memiliki Kategori!')),
          );
          return;
        }
      }

      List<TransactionItem> newTransactions = [];
      for (var draft in _drafts) {
        final category = provider.getCategoryForSub(draft.subCategory!);
        final amount = double.parse(draft.amountController.text);
        newTransactions.add(TransactionItem(
          id: '',
          timestamp: DateTime.now(),
          date: _selectedDate,
          category: category,
          subCategory: draft.subCategory!,
          amount: amount,
          description: draft.descriptionController.text,
        ));
      }

      final result = await provider.addTransactions(newTransactions);

      if (!mounted) return;

      if (result.savedOffline) {
        // Saved to offline queue
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.accentGold,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.cloud_off_rounded, color: Colors.black87),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${newTransactions.length} transaksi disimpan offline. Akan sync otomatis saat ada internet.',
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (result.success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.primaryGreen,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.black87),
                const SizedBox(width: 8),
                Text('${newTransactions.length} transaksi berhasil disimpan!',
                    style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.danger,
            duration: const Duration(seconds: 6),
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.errorMessage.isNotEmpty
                        ? provider.errorMessage
                        : 'Gagal menyimpan.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FinanceProvider>(context);
    List<String> availableSubCats = provider.getAvailableSubCategories();

    for (var draft in _drafts) {
      if (draft.subCategory != null && !availableSubCats.contains(draft.subCategory)) {
        availableSubCats.add(draft.subCategory!);
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : Colors.white;
    final borderColor = isDark ? AppTheme.darkCardBorder : Colors.grey.shade200;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Transaksi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isProcessingOcr
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 3, color: AppTheme.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Membaca nota dengan AI...', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Harap tunggu sebentar', style: TextStyle(color: Color(0xFF8899BB), fontSize: 13)),
                ],
              ),
            )
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      children: [
                        // Scan buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                                label: const Text('Scan Kamera'),
                                onPressed: () => _scanReceipt(ImageSource.camera),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.photo_library_rounded, size: 18),
                                label: const Text('Galeri'),
                                onPressed: () => _scanReceipt(ImageSource.gallery),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Date selector
                        InkWell(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime(2100),
                            );
                            if (date != null) {
                              setState(() => _selectedDate = date);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primaryGreen),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Tanggal Transaksi', style: TextStyle(fontSize: 11, color: Color(0xFF8899BB))),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(_selectedDate),
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFF8899BB)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Item count badge
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_drafts.length} Item',
                            style: const TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Items list
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _drafts.length,
                      itemBuilder: (context, index) {
                        final draft = _drafts[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 28, height: 28,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryGreen.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text('${index + 1}',
                                              style: const TextStyle(
                                                  color: AppTheme.primaryGreen,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13)),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text('Item', style: TextStyle(color: Color(0xFF8899BB), fontWeight: FontWeight.w500, fontSize: 13)),
                                    ],
                                  ),
                                  if (_drafts.length > 1)
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          draft.dispose();
                                          _drafts.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        width: 30, height: 30,
                                        decoration: BoxDecoration(
                                          color: AppTheme.danger.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.close_rounded, color: AppTheme.danger, size: 16),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: draft.amountController,
                                decoration: const InputDecoration(
                                  labelText: 'Nominal',
                                  prefixText: 'Rp ',
                                  prefixStyle: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                                validator: (value) {
                                  if (value == null || value.isEmpty) return 'Masukkan nominal';
                                  if (double.tryParse(value) == null) return 'Nominal tidak valid';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Sub-Kategori',
                                ),
                                value: draft.subCategory,
                                items: availableSubCats.map((cat) {
                                  final parentCat = provider.getCategoryForSub(cat);
                                  return DropdownMenuItem(
                                    value: cat,
                                    child: Text('$cat ($parentCat)',
                                        style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => draft.subCategory = val);
                                },
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: draft.descriptionController,
                                decoration: const InputDecoration(
                                  labelText: 'Keterangan (Opsional)',
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  // Footer
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      border: Border(
                        top: BorderSide(color: borderColor),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                          label: const Text('Tambah Item'),
                          onPressed: () {
                            setState(() => _drafts.add(_createEmptyDraft()));
                          },
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: provider.isLoading ? null : _saveTransactions,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: provider.isLoading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(
                                  'Simpan ${_drafts.length} Transaksi',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
