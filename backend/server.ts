import app from './src/app';

// 環境変数からポートを取得するか、デフォルト値（3000）を使用
// ※型エラー防止のため Number() で囲むのが安全ですが、そのままでも動きます
const PORT = Number(process.env.PORT) || 3000;

// サーバーを起動
// ★変更点: 第2引数に '0.0.0.0' を追加してください
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 サーバーはポート ${PORT} で稼働中です。`);
  console.log(`アクセス: http://localhost:${PORT}`);
});