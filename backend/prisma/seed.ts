import { PrismaClient } from '@prisma/client';
import * as fs from 'fs';       // 👈 修正: * as fs に変更
import * as path from 'path';   // 👈 修正: * as path に変更
import { fileURLToPath } from 'url'; // 👈 追加

const prisma = new PrismaClient();

// ▼▼▼ __dirname を自分で定義する（エラー回避の呪文） ▼▼▼
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
// ▲▲▲ 追加ここまで ▲▲▲

async function main() {
  // 1. CSVファイルのパスを指定
  const csvFilePath = path.join(__dirname, 'stores_rows.csv');
  
  console.log(`📂 CSVファイルを読み込んでいます... Path: ${csvFilePath}`);

  // ファイルが存在するか確認
  if (!fs.existsSync(csvFilePath)) {
    console.error('❌ CSVファイルが見つかりません。backend/prisma/stores_rows.csv に配置してください。');
    return;
  }

  // 2. ファイルを読み込む
  const csvData = fs.readFileSync(csvFilePath, 'utf8');

  // 3. 行ごとに分割する
  const rows = csvData.split(/\r?\n/);

  // 4. 1行ずつ処理する
  let count = 0;
  for (const row of rows.slice(1)) {
    if (!row.trim()) continue;

    const columns = row.split(',');
    if (columns.length < 2) continue;

    const code = columns[0].trim();
    const name = columns[1].trim();

    // データベースに登録
    await prisma.store.upsert({
      where: { code: code },
      update: { name: name },
      create: {
        code: code,
        name: name,
      },
    });
    
    count++;
    if (count % 100 === 0) {
      console.log(`   ... ${count} 件処理しました`);
    }
  }

  console.log(`✅ 完了！ 合計 ${count} 店舗のデータを登録しました。`);
}

main()
  .catch((e) => {
    console.error('❌ エラーが発生しました:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });