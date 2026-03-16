import 'package:flutter/material.dart';

import '../../core/theme/stitch_theme.dart';
import '../../data/services/mobile_api_service.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
    required this.token,
    required this.apiService,
    required this.canManage,
    required this.canDelete,
  });

  final String token;
  final MobileApiService apiService;
  final bool canManage;
  final bool canDelete;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  bool loading = false;
  String message = '';
  List<Map<String, dynamic>> products = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> categories = <Map<String, dynamic>>[];

  int? editingId;
  final TextEditingController codeCtrl = TextEditingController();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController unitCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();
  final TextEditingController descCtrl = TextEditingController();
  int? selectedCategoryId;
  bool isActive = true;

  int? editingCategoryId;
  final TextEditingController categoryCodeCtrl = TextEditingController();
  final TextEditingController categoryNameCtrl = TextEditingController();
  final TextEditingController categoryDescCtrl = TextEditingController();
  bool categoryIsActive = true;

  final TextEditingController searchCtrl = TextEditingController();
  String activeFilter = '';
  int? categoryFilterId;

  int? _parseId(dynamic value) {
    if (value is int) return value;
    if (value == null) return null;
    return int.tryParse(value.toString());
  }

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  @override
  void dispose() {
    codeCtrl.dispose();
    nameCtrl.dispose();
    unitCtrl.dispose();
    priceCtrl.dispose();
    descCtrl.dispose();
    categoryCodeCtrl.dispose();
    categoryNameCtrl.dispose();
    categoryDescCtrl.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait<void>(<Future<void>>[
      _fetchCategories(),
      _fetchProducts(),
    ]);
  }

  Future<void> _fetchCategories() async {
    final List<Map<String, dynamic>> rows = await widget.apiService
        .getProductCategories(widget.token);
    if (!mounted) return;
    setState(() {
      categories = rows;
    });
  }

  Future<void> _fetchProducts() async {
    setState(() => loading = true);
    final List<Map<String, dynamic>> rows = await widget.apiService.getProducts(
      widget.token,
      search: searchCtrl.text.trim(),
      isActive: activeFilter,
      categoryId: categoryFilterId,
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      products = rows;
    });
  }

  void _resetForm() {
    editingId = null;
    codeCtrl.clear();
    nameCtrl.clear();
    unitCtrl.clear();
    priceCtrl.clear();
    descCtrl.clear();
    selectedCategoryId = null;
    isActive = true;
    message = '';
  }

  void _resetCategoryForm() {
    editingCategoryId = null;
    categoryCodeCtrl.clear();
    categoryNameCtrl.clear();
    categoryDescCtrl.clear();
    categoryIsActive = true;
    message = '';
  }

  Future<bool> _save() async {
    if (!widget.canManage) {
      setState(() => message = 'Bạn không có quyền quản lý sản phẩm.');
      return false;
    }
    if (nameCtrl.text.trim().isEmpty) {
      setState(() => message = 'Vui lòng nhập tên sản phẩm.');
      return false;
    }
    final double? price = double.tryParse(priceCtrl.text.trim());
    final bool ok = editingId == null
        ? await widget.apiService.createProduct(
            widget.token,
            code: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
            name: nameCtrl.text.trim(),
            categoryId: selectedCategoryId,
            unit: unitCtrl.text.trim().isEmpty ? null : unitCtrl.text.trim(),
            unitPrice: price,
            description:
                descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
            isActive: isActive,
          )
        : await widget.apiService.updateProduct(
            widget.token,
            editingId!,
            code: codeCtrl.text.trim().isEmpty ? null : codeCtrl.text.trim(),
            name: nameCtrl.text.trim(),
            categoryId: selectedCategoryId,
            unit: unitCtrl.text.trim().isEmpty ? null : unitCtrl.text.trim(),
            unitPrice: price,
            description:
                descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
            isActive: isActive,
          );
    if (!mounted) return false;
    setState(() {
      message = ok ? 'Đã lưu sản phẩm.' : 'Lưu sản phẩm thất bại.';
    });
    if (ok) {
      _resetForm();
      await _fetchProducts();
    }
    return ok;
  }

  Future<bool> _saveCategory() async {
    if (!widget.canManage) {
      setState(() => message = 'Bạn không có quyền quản lý danh mục.');
      return false;
    }
    if (categoryNameCtrl.text.trim().isEmpty) {
      setState(() => message = 'Vui lòng nhập tên danh mục.');
      return false;
    }
    final bool ok = editingCategoryId == null
        ? await widget.apiService.createProductCategory(
            widget.token,
            code: categoryCodeCtrl.text.trim().isEmpty
                ? null
                : categoryCodeCtrl.text.trim(),
            name: categoryNameCtrl.text.trim(),
            description: categoryDescCtrl.text.trim().isEmpty
                ? null
                : categoryDescCtrl.text.trim(),
            isActive: categoryIsActive,
          )
        : await widget.apiService.updateProductCategory(
            widget.token,
            editingCategoryId!,
            code: categoryCodeCtrl.text.trim().isEmpty
                ? null
                : categoryCodeCtrl.text.trim(),
            name: categoryNameCtrl.text.trim(),
            description: categoryDescCtrl.text.trim().isEmpty
                ? null
                : categoryDescCtrl.text.trim(),
            isActive: categoryIsActive,
          );
    if (!mounted) return false;
    setState(() {
      message = ok ? 'Đã lưu danh mục.' : 'Lưu danh mục thất bại.';
    });
    if (ok) {
      _resetCategoryForm();
      await _fetchCategories();
    }
    return ok;
  }

  Future<void> _delete(int id) async {
    if (!widget.canDelete) {
      setState(() => message = 'Bạn không có quyền xóa sản phẩm.');
      return;
    }
    final bool ok = await widget.apiService.deleteProduct(widget.token, id);
    if (!mounted) return;
    setState(() => message = ok ? 'Đã xóa sản phẩm.' : 'Xóa sản phẩm thất bại.');
    if (ok) await _fetchProducts();
  }

  Future<void> _deleteCategory(int id) async {
    if (!widget.canDelete) {
      setState(() => message = 'Bạn không có quyền xóa danh mục.');
      return;
    }
    final bool ok = await widget.apiService.deleteProductCategory(widget.token, id);
    if (!mounted) return;
    setState(() => message = ok ? 'Đã xóa danh mục.' : 'Xóa danh mục thất bại.');
    if (ok) {
      await _fetchCategories();
      if (categoryFilterId == id) {
        setState(() => categoryFilterId = null);
        await _fetchProducts();
      }
    }
  }

  Future<void> _openForm({Map<String, dynamic>? product}) async {
    setState(() {
      message = '';
      if (product == null) {
        _resetForm();
      } else {
        editingId = _parseId(product['id']);
        codeCtrl.text = (product['code'] ?? '').toString();
        nameCtrl.text = (product['name'] ?? '').toString();
        unitCtrl.text = (product['unit'] ?? '').toString();
        priceCtrl.text = (product['unit_price'] ?? '').toString();
        descCtrl.text = (product['description'] ?? '').toString();
        isActive = (product['is_active'] ?? true) == true;
        selectedCategoryId = _parseId(product['category_id']);
      }
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: StitchTheme.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      editingId == null ? 'Tạo sản phẩm' : 'Sửa sản phẩm',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Mã sản phẩm'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Tên sản phẩm'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int?>(
                      value: selectedCategoryId,
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Chọn danh mục'),
                        ),
                        ...categories.map((Map<String, dynamic> category) {
                          final int? id = _parseId(category['id']);
                          return DropdownMenuItem<int?>(
                            value: id,
                            child: Text((category['name'] ?? '').toString()),
                          );
                        }),
                      ],
                      onChanged: (int? value) {
                        setSheetState(() => selectedCategoryId = value);
                      },
                      decoration:
                          const InputDecoration(labelText: 'Danh mục sản phẩm'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: unitCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Đơn vị'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: priceCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Đơn giá'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Đang hoạt động'),
                      value: isActive,
                      onChanged: (bool value) =>
                          setSheetState(() => isActive = value),
                    ),
                    if (message.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final bool ok = await _save();
                              if (!context.mounted) return;
                              if (ok) {
                                Navigator.of(context).pop();
                              } else {
                                setSheetState(() {});
                              }
                            },
                            child: Text(
                              editingId == null
                                  ? 'Lưu sản phẩm'
                                  : 'Cập nhật',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted) return;
    setState(() => _resetForm());
  }

  Future<void> _openCategoryForm({Map<String, dynamic>? category}) async {
    setState(() {
      message = '';
      if (category == null) {
        _resetCategoryForm();
      } else {
        editingCategoryId = _parseId(category['id']);
        categoryCodeCtrl.text = (category['code'] ?? '').toString();
        categoryNameCtrl.text = (category['name'] ?? '').toString();
        categoryDescCtrl.text = (category['description'] ?? '').toString();
        categoryIsActive = (category['is_active'] ?? true) == true;
      }
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: StitchTheme.bg,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      editingCategoryId == null
                          ? 'Tạo danh mục'
                          : 'Sửa danh mục',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryCodeCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Mã danh mục'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: categoryNameCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Tên danh mục'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: categoryDescCtrl,
                      decoration: const InputDecoration(labelText: 'Mô tả'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Đang hoạt động'),
                      value: categoryIsActive,
                      onChanged: (bool value) =>
                          setSheetState(() => categoryIsActive = value),
                    ),
                    if (message.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: const TextStyle(color: StitchTheme.textMuted),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Hủy'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final bool ok = await _saveCategory();
                              if (!context.mounted) return;
                              if (ok) {
                                Navigator.of(context).pop();
                              } else {
                                setSheetState(() {});
                              }
                            },
                            child: Text(
                              editingCategoryId == null
                                  ? 'Lưu danh mục'
                                  : 'Cập nhật',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted) return;
    setState(() => _resetCategoryForm());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sản phẩm & danh mục'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchAll,
          ),
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openForm(),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: <Widget>[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Expanded(
                            child: Text(
                              'Bộ lọc sản phẩm',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _fetchProducts,
                            icon: const Icon(Icons.filter_alt_outlined, size: 16),
                            label: const Text('Lọc'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: searchCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tìm theo mã hoặc tên',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: activeFilter,
                              decoration: const InputDecoration(
                                labelText: 'Trạng thái',
                              ),
                              items: const <DropdownMenuItem<String>>[
                                DropdownMenuItem<String>(
                                  value: '',
                                  child: Text('Tất cả'),
                                ),
                                DropdownMenuItem<String>(
                                  value: '1',
                                  child: Text('Đang hoạt động'),
                                ),
                                DropdownMenuItem<String>(
                                  value: '0',
                                  child: Text('Ngưng'),
                                ),
                              ],
                              onChanged: (String? value) {
                                setState(() => activeFilter = value ?? '');
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int?>(
                              value: categoryFilterId,
                              decoration: const InputDecoration(
                                labelText: 'Danh mục',
                              ),
                              items: <DropdownMenuItem<int?>>[
                                const DropdownMenuItem<int?>(
                                  value: null,
                                  child: Text('Tất cả'),
                                ),
                                ...categories.map((Map<String, dynamic> category) {
                                  final int? id = _parseId(category['id']);
                                  return DropdownMenuItem<int?>(
                                    value: id,
                                    child: Text(
                                      (category['name'] ?? '').toString(),
                                    ),
                                  );
                                }),
                              ],
                              onChanged: (int? value) {
                                setState(() => categoryFilterId = value);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Danh mục sản phẩm',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (widget.canManage)
                    ElevatedButton.icon(
                      onPressed: () => _openCategoryForm(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Thêm danh mục'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (categories.isEmpty)
                const Text(
                  'Chưa có danh mục.',
                  style: TextStyle(color: StitchTheme.textMuted),
                )
              else
                ...categories.map((Map<String, dynamic> category) {
                  final int categoryId = _parseId(category['id']) ?? 0;
                  return Card(
                    child: ListTile(
                      title: Text((category['name'] ?? '').toString()),
                      subtitle: Text(
                        '${category['code'] ?? ''} • ${category['description'] ?? ''}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: <Widget>[
                          if (widget.canManage)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () =>
                                  _openCategoryForm(category: category),
                            ),
                          if (widget.canDelete)
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              onPressed: () => _deleteCategory(categoryId),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  const Expanded(
                    child: Text(
                      'Danh sách sản phẩm',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (widget.canManage)
                    ElevatedButton.icon(
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Thêm mới'),
                    ),
                ],
              ),
              if (message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    message,
                    style: const TextStyle(color: StitchTheme.textMuted),
                  ),
                ),
              const SizedBox(height: 12),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else if (products.isEmpty)
                const Text(
                  'Chưa có sản phẩm phù hợp bộ lọc.',
                  style: TextStyle(color: StitchTheme.textMuted),
                )
              else
                ...products.map((Map<String, dynamic> product) {
                  final int productId = _parseId(product['id']) ?? 0;
                  final String categoryName =
                      (product['category']?['name'] ?? 'Không có danh mục')
                          .toString();
                  return Card(
                    child: ListTile(
                      title: Text((product['name'] ?? '').toString()),
                      subtitle: Text(
                        '${product['code'] ?? ''} • $categoryName • ${(product['unit_price'] ?? '').toString()}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _openForm(product: product),
                          ),
                          if (widget.canDelete)
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              onPressed: () => _delete(productId),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
