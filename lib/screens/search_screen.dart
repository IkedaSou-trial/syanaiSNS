import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';
import '../widgets/empty_state.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _apiService = ApiService();

  final ExpansionTileController _expansionController =
      ExpansionTileController();

  final _displayNameController = TextEditingController();
  final _storeCodeController = TextEditingController();
  final _keywordController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  // ▼▼▼ 追加: カテゴリー選択用 ▼▼▼
  final List<String> _categories = [
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
  String? _selectedCategory; // 選択されたカテゴリー (nullなら指定なし)

  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  ImageProvider? _getImageProvider(String? url) {
    if (url == null) return null;
    if (url.startsWith('data:')) {
      try {
        final base64Str = url.split(',')[1];
        return MemoryImage(base64Decode(base64Str));
      } catch (e) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  Future<void> _doSearch() async {
    if (_expansionController.isExpanded) {
      _expansionController.collapse();
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    // ▼▼▼ 修正: カテゴリー(_selectedCategory)も渡す ▼▼▼
    final results = await _apiService.getPosts(
      displayName: _displayNameController.text,
      storeCode: _storeCodeController.text,
      keyword: _keywordController.text,
      startDate: _startDate,
      endDate: _endDate,
      category: _selectedCategory, // 追加
    );

    if (mounted) {
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _displayNameController.clear();
    _storeCodeController.clear();
    _keywordController.clear();
    setState(() {
      _startDate = null;
      _endDate = null;
      _selectedCategory = null; // カテゴリーもリセット
      _searchResults = [];
      _hasSearched = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    String dateText = '期間を指定';
    if (_startDate != null) {
      final startStr = "${_startDate!.month}/${_startDate!.day}";
      if (_endDate != null && _startDate != _endDate) {
        final endStr = "${_endDate!.month}/${_endDate!.day}";
        dateText = "$startStr 〜 $endStr";
      } else {
        dateText = startStr;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('検索'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearSearch,
            tooltip: '条件をクリア',
          ),
        ],
      ),
      body: Column(
        children: [
          ExpansionTile(
            controller: _expansionController,
            title: const Text('検索条件を入力'),
            initiallyExpanded: true,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    // カテゴリー選択ドロップダウン (DropdownButtonFormFieldを使用)
                    // ▼▼▼ 追加 ▼▼▼
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'カテゴリー',
                        prefixIcon: Icon(Icons.category, color: Colors.grey),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('指定なし (すべて)'),
                        ),
                        ..._categories.map((String category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          );
                        }),
                      ],
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedCategory = newValue;
                        });
                      },
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _displayNameController,
                            decoration: const InputDecoration(labelText: '表示名'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _storeCodeController,
                            decoration: const InputDecoration(
                              labelText: '店舗コード',
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: _keywordController,
                      decoration: const InputDecoration(
                        labelText: 'キーワード (本文)',
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _selectDateRange,
                            child: Text(dateText),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _doSearch,
                      icon: const Icon(Icons.search),
                      label: const Text('検索する'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                        backgroundColor: const Color(0xFF1A237E), // ネイビーに変更
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_hasSearched
                ? const EmptyState(
                    title: '投稿を検索',
                    message: 'カテゴリーやキーワードを指定して\n他の店舗の取り組みを探してみましょう',
                    icon: Icons.search,
                  )
                : _searchResults.isEmpty
                ? const EmptyState(
                    title: '見つかりませんでした',
                    message: '条件を変更して再度お試しください',
                    icon: Icons.sentiment_dissatisfied,
                  )
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final post = _searchResults[index];
                      final author = post['author'];
                      final String category =
                          post['category'] ?? 'その他'; // カテゴリー取得

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        elevation: 2,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pushNamed('/post_detail', arguments: post);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. ユーザー情報 + カテゴリーラベル
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage: _getImageProvider(
                                        author?['profileImageUrl'],
                                      ),
                                      child: author?['profileImageUrl'] == null
                                          ? const Icon(Icons.person, size: 16)
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        author?['displayName'] ?? '不明',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // ▼▼▼ カテゴリーラベル表示 ▼▼▼
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        category,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.black54,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      DateFormatter.timeAgo(post['createdAt']),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // 2. 本文
                                Text(
                                  post['content'] ?? '',
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16),
                                ),

                                // 3. 画像があれば表示
                                if (post['imageUrl'] != null) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image(
                                      image: _getImageProvider(
                                        post['imageUrl'],
                                      )!,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
}
