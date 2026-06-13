import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/book_model.dart';
import '../../providers/book_provider.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';

/// Admin-only screen to add or edit a book.
class AddEditBookScreen extends StatefulWidget {
  final BookModel? book; // null = add mode, non-null = edit mode
  const AddEditBookScreen({super.key, this.book});

  @override
  State<AddEditBookScreen> createState() => _AddEditBookScreenState();
}

class _AddEditBookScreenState extends State<AddEditBookScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _authorCtrl;
  late final TextEditingController _isbnCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _copiesCtrl;
  late String _selectedCategory;
  File? _coverImage;
  bool _isSaving = false;

  bool get _isEdit => widget.book != null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.book?.title ?? '');
    _authorCtrl = TextEditingController(text: widget.book?.author ?? '');
    _isbnCtrl = TextEditingController(text: widget.book?.isbn ?? '');
    _descCtrl = TextEditingController(text: widget.book?.description ?? '');
    _copiesCtrl = TextEditingController(
      text: widget.book?.totalCopies.toString() ?? '1',
    );
    _selectedCategory =
        widget.book?.category ?? AppConstants.bookCategories.first;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _isbnCtrl.dispose();
    _descCtrl.dispose();
    _copiesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _coverImage = File(picked.path));
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final provider = context.read<BookProvider>();
    bool success;

    if (_isEdit) {
      success = await provider.updateBook(
        existing: widget.book!,
        title: _titleCtrl.text,
        author: _authorCtrl.text,
        isbn: _isbnCtrl.text,
        category: _selectedCategory,
        description: _descCtrl.text,
        totalCopies: int.parse(_copiesCtrl.text),
        coverImage: _coverImage,
      );
    } else {
      success = await provider.addBook(
        title: _titleCtrl.text,
        author: _authorCtrl.text,
        isbn: _isbnCtrl.text,
        category: _selectedCategory,
        description: _descCtrl.text,
        totalCopies: int.parse(_copiesCtrl.text),
        coverImage: _coverImage,
      );
    }

    setState(() => _isSaving = false);

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEdit ? 'Book updated' : 'Book added')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Save failed'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Book' : 'Add Book')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cover Image Picker ──
              Center(child: _buildCoverPicker()),
              const SizedBox(height: 24),

              // ── Title ──
              TextFormField(
                controller: _titleCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  prefixIcon: Icon(Icons.title),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Title is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // ── Author ──
              TextFormField(
                controller: _authorCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Author *',
                  prefixIcon: Icon(Icons.person_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Author is required'
                    : null,
              ),
              const SizedBox(height: 16),

              // ── ISBN ──
              TextFormField(
                controller: _isbnCtrl,
                decoration: const InputDecoration(
                  labelText: 'ISBN',
                  prefixIcon: Icon(Icons.qr_code),
                ),
              ),
              const SizedBox(height: 16),

              // ── Category Dropdown ──
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: AppConstants.bookCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _selectedCategory = v);
                },
              ),
              const SizedBox(height: 16),

              // ── Total Copies ──
              TextFormField(
                controller: _copiesCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total Copies *',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  final n = int.tryParse(v);
                  if (n == null || n < 1) return 'Must be at least 1';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ── Description ──
              TextFormField(
                controller: _descCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  prefixIcon: Padding(
                    padding: EdgeInsets.only(bottom: 60),
                    child: Icon(Icons.description_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Save Button ──
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Text(_isEdit ? 'Update Book' : 'Add Book'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverPicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: 140,
        height: 200,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.primaryColor.withAlpha(50)),
          image: _coverImage != null
              ? DecorationImage(
                  image: FileImage(_coverImage!),
                  fit: BoxFit.cover,
                )
              : (widget.book?.coverUrl.isNotEmpty == true
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(widget.book!.coverUrl),
                        fit: BoxFit.cover,
                      )
                    : null),
        ),
        child: _coverImage == null && (widget.book?.coverUrl.isEmpty ?? true)
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 40,
                    color: AppTheme.primaryColor,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Add Cover',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
