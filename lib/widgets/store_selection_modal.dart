import 'package:flutter/material.dart';
import '../services/api_service.dart';

class StoreSelectionModal extends StatefulWidget {
  const StoreSelectionModal({super.key});

  @override
  State<StoreSelectionModal> createState() => _StoreSelectionModalState();
}

class _StoreSelectionModalState extends State<StoreSelectionModal> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allStores = []; // 全データ
  List<dynamic> _filteredStores = []; // 検索結果
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStores();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 店舗データを取得
  Future<void> _fetchStores() async {
    final stores = await _apiService.getStores();
    if (mounted) {
      setState(() {
        _allStores = stores;
        _filteredStores = stores; //最初は全件表示
        _isLoading = false;
      });
    }
  }

  // 検索文字が変わった時の処理
  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStores = _allStores.where((store) {
        final code = store['code'].toString().toLowerCase();
        final name = store['name'].toString().toLowerCase();
        // コードか名前に検索文字が含まれていればOK
        return code.contains(query) || name.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8, // 画面の8割の高さ
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ハンドルバー（つまみ）
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            '店舗を選択',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // 検索ボックス
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: '店舗名またはコードを入力',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 16),
          // リスト表示
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredStores.isEmpty
                ? const Center(child: Text('見つかりませんでした'))
                : ListView.builder(
                    itemCount: _filteredStores.length,
                    itemBuilder: (context, index) {
                      final store = _filteredStores[index];
                      return ListTile(
                        title: Text(store['name']),
                        subtitle: Text('コード: ${store['code']}'),
                        leading: const Icon(Icons.store, color: Colors.blue),
                        onTap: () {
                          // 選んだデータを返して閉じる
                          Navigator.pop(context, store);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
