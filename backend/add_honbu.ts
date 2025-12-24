import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  // コード '0'、名前 '本部' のデータを追加（既にあれば何もしない）
  const honbu = await prisma.store.upsert({
    where: { code: '0' },
    update: {}, // 既にある場合は何もしない
    create: {
      code: '0',
      name: '本部',
    },
  });

  console.log('✅ 成功しました！以下のデータを追加（または確認）しました:');
  console.log(honbu);
}

main()
  .catch((e) => {
    console.error('❌ エラーが発生しました:');
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });