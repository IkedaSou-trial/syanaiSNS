import * as express from 'express';
import prisma from '../lib/prisma';
import { authenticateJWT_Optional } from '../auth/auth.middleware';

const rankingRouter = express.Router();

// 店舗ランキング取得（総フォロワー数順）
rankingRouter.get('/stores', authenticateJWT_Optional, async (req, res) => {
  try {
    // 全店舗と、そこに所属するユーザーのフォロワー数を取得
    const stores = await prisma.store.findMany({
      include: {
        users: {
          select: {
            _count: {
              select: { followedBy: true } // フォロワー数をカウント
            }
          }
        }
      }
    });

    // 店舗ごとにフォロワー数を合計する
    const result = stores.map(store => {
      const totalFollowers = store.users.reduce((sum, user) => sum + user._count.followedBy, 0);
      return {
        id: store.id,
        code: store.code,
        name: store.name,
        totalFollowers,
        memberCount: store.users.length
      };
    });

    // 多い順に並び替え
    result.sort((a, b) => b.totalFollowers - a.totalFollowers);

    res.json(result);
  } catch (error) {
    console.error('Store ranking error:', error);
    res.status(500).json({ error: 'ランキングの取得に失敗しました' });
  }
});

// 特定店舗内のユーザーランキング取得
rankingRouter.get('/stores/:code/users', authenticateJWT_Optional, async (req, res) => {
  const { code } = req.params;
  try {
    const users = await prisma.user.findMany({
      where: { storeCode: code },
      include: {
        store: true,
        _count: { select: { followedBy: true } }
      }
    });
    
    const result = users.map(user => ({
      id: user.id,
      username: user.username,
      displayName: user.store ? `${user.displayName}＠${user.store.name}` : user.displayName,
      profileImageUrl: user.profileImageUrl,
      followerCount: user._count.followedBy
    }));
    
    // フォロワー数が多い順にソート
    result.sort((a, b) => b.followerCount - a.followerCount);
    
    res.json(result);
  } catch (error) {
    console.error('Store users ranking error:', error);
    res.status(500).json({ error: 'ユーザーリストの取得に失敗しました' });
  }
});

export default rankingRouter;