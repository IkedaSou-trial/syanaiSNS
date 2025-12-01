import app from './src/app';

// 環境変数からポートを取得するか、デフォルト値（3000）を使用
const PORT = process.env.PORT || 3000;

// サーバーを起動
app.listen(PORT, () => {
  console.log(`🚀 サーバーはポート ${PORT} で稼働中です。`);
  console.log(`アクセス: http://localhost:${PORT}`);
});