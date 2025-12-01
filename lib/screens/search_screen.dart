import 'dart:convert'; // 💡 Base64デコード用
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/date_formatter.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _apiService = ApiService();

  // 💡 追加: ExpansionTile を操作するためのコントローラー
  final ExpansionTileController _expansionController =
      ExpansionTileController();

  final _displayNameController = TextEditingController();
  final _storeCodeController = TextEditingController();
  final _keywordController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  // 画像表示用ヘルパー
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
    // 💡 検索実行時にアコーディオンを閉じる
    if (_expansionController.isExpanded) {
      _expansionController.collapse();
    }

    // キーボードを閉じる
    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    final results = await _apiService.getPosts(
      displayName: _displayNameController.text,
      storeCode: _storeCodeController.text,
      keyword: _keywordController.text,
      startDate: _startDate,
      endDate: _endDate,
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
            // 💡 コントローラーを紐付け
            controller: _expansionController,
            title: const Text('検索条件を入力'),
            initiallyExpanded: true,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
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
                ? const Center(child: Text('条件を入力して検索してください'))
                : _searchResults.isEmpty
                ? const Center(child: Text('該当する投稿はありません'))
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final post = _searchResults[index];
                      final author = post['author'];

                      // 💡 ListTile ではなく Card + Column でレイアウトを作り直しました
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
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
                                // 1. ユーザー情報
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
                                    Text(
                                      author?['displayName'] ?? '不明',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
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

                                // 3. 💡 画像があれば表示
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
