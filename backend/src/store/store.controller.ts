import * as express from 'express';
import { PrismaClient } from '@prisma/client';

const storeRouter = express.Router();
const prisma = new PrismaClient();

// 店舗一覧取得 (検索機能付き)
storeRouter.get('/', async (req, res) => {
  try {
    const stores = await prisma.store.findMany({
      orderBy: { code: 'asc' }, // コード順に並べる
    });
    res.json(stores);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: '店舗データの取得に失敗しました' });
  }
});

export default storeRouter;