import app from './src/app';

// 環境変数からポートを取得
const PORT = Number(process.env.PORT) || 3000;

// サーバーを起動
app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 サーバーはポート ${PORT} で稼働中です。`);
  console.log(`アクセス: http://localhost:${PORT}`);
});