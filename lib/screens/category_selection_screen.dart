import 'package:flutter/material.dart';
import '../services/api_service.dart';

class CategorySelectionScreen extends StatefulWidget {
  const CategorySelectionScreen({super.key});

  @override
  State<CategorySelectionScreen> createState() =>
      _CategorySelectionScreenState();
}

class _CategorySelectionScreenState extends State<CategorySelectionScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  // ▼▼▼ 修正: 新しいカテゴリーリスト ▼▼▼
  final List<String> _allCategories = [
    '惣菜',
    '精肉',
    '青果',
    '鮮魚',
    'グロサリー',
    'デイリー',
    '生活',
    'ライフスタイル',
    'ソフト',
    'ハード',
    '家電',
    'ペット',
    '後方',
  ];

  List<String> _selectedCategories = [];
  Map<String, dynamic>? _currentUser;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map<String, dynamic>) {
      _currentUser = args;
      if (args['interestedCategories'] != null) {
        // 保存されているデータが古いカテゴリーを含んでいる可能性があるので、
        // 現在のリストに含まれるものだけを有効にするフィルタリングを入れると安全です
        final savedList = List<String>.from(args['interestedCategories']);
        _selectedCategories = savedList
            .where((c) => _allCategories.contains(c))
            .toList();
      }
    }
  }

  // ▼▼▼ 追加: 「全て」ボタンの処理 ▼▼▼
  void _toggleAll(bool? value) {
    setState(() {
      if (value == true) {
        // 全て追加
        _selectedCategories = List.from(_allCategories);
      } else {
        // 全てクリア
        _selectedCategories.clear();
      }
    });
  }

  Future<void> _saveAndGoHome() async {
    if (_currentUser == null) return;

    // 0個でも保存できるようにするか、警告するかはお好みで。
    // 今回は「何も見たくない」もあり得るので警告なしで通すか、
    // あるいは以前通り警告するか。一旦以前のまま警告を入れておきます。
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('少なくとも1つのカテゴリーを選択してください')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await _apiService.updateCategories(
        _currentUser!['id'].toString(),
        _selectedCategories,
      );

      if (!mounted) return;

      if (success) {
        _currentUser!['interestedCategories'] = _selectedCategories;
        if (Navigator.canPop(context)) {
          Navigator.pop(context, _currentUser);
        } else {
          Navigator.of(
            context,
          ).pushReplacementNamed('/home', arguments: _currentUser);
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('保存に失敗しました')));
      }
    } catch (e) {
      print(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 全て選択されているかどうかの判定
    final bool isAllSelected =
        _selectedCategories.length == _allCategories.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('カテゴリー選択'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'タイムラインに表示したい\nカテゴリーを選択してください',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ▼▼▼ 追加: 「全て」チェックボックス ▼▼▼
                      Card(
                        color: isAllSelected
                            ? const Color(0xFFC5CAE9)
                            : Colors.white, // 少し濃い青
                        elevation: 2,
                        child: CheckboxListTile(
                          title: const Text(
                            '全て',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          value: isAllSelected,
                          activeColor: const Color(0xFF1A237E),
                          onChanged: _toggleAll,
                          secondary: const Icon(Icons.done_all),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(), // 区切り線
                      const SizedBox(height: 8),

                      // 個別のカテゴリーリスト
                      ..._allCategories.map((category) {
                        final isSelected = _selectedCategories.contains(
                          category,
                        );
                        return Card(
                          color: isSelected ? const Color(0xFFE8EAF6) : null,
                          child: CheckboxListTile(
                            title: Text(
                              category,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFF1A237E)
                                    : null,
                              ),
                            ),
                            value: isSelected,
                            activeColor: const Color(0xFF1A237E),
                            onChanged: (bool? checked) {
                              setState(() {
                                if (checked == true) {
                                  _selectedCategories.add(category);
                                } else {
                                  _selectedCategories.remove(category);
                                }
                              });
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveAndGoHome,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        '決定して進む',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
