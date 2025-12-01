import { PrismaClient } from '@prisma/client';

// PrismaClientのインスタンスを生成します。
// アプリケーション全体でシングルトン（単一のインスタンス）として使用します。
const prisma = new PrismaClient({
  log: ['query', 'info', 'warn', 'error'], // 開発中にクエリログなどを出力する設定
});

export default prisma;