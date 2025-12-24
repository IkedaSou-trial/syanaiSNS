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

rankingRouter.get('/:period', authenticateJWT_Optional, async (req, res) => {
  const { period } = req.params;

  try {
    const now = new Date();
    let startDate = new Date();

    if (period === 'weekly') {
      startDate.setDate(now.getDate() - 7);
    } else if (period === 'monthly') {
      startDate.setMonth(now.getMonth() - 1);
    } else {
      startDate.setDate(now.getDate() - 7);
    }

    const posts = await prisma.post.findMany({
      where: {
        createdAt: {
          gte: startDate,
        },
      },
      include: {
        author: {
          select: {
            username: true,
            displayName: true,
            profileImageUrl: true,
            store: { select: { name: true } }
          }
        },
        _count: {
          select: {
            likes: true,
            mimics: true,
          }
        }
      }
    });

    // ▼▼▼ 修正箇所： post の後ろに : any をつけました ▼▼▼
    const ranking = posts.map((post: any) => {
      // こうすることで、TypeScriptに「postの中身は何が入っていても文句を言うな」と伝えます
      const score = (post._count.mimics * 2) + post._count.likes;
      
      return {
        id: post.id,
        content: post.content,
        imageUrl: post.imageUrl,
        createdAt: post.createdAt,
        author: {
          username: post.author?.username, // ?をつけて安全にアクセス
          displayName: post.author?.store 
             ? `${post.author.displayName}＠${post.author.store.name}` 
             : post.author?.displayName || '不明',
          profileImageUrl: post.author?.profileImageUrl,
        },
        likeCount: post._count.likes,
        copyCount: post._count.mimics,
        score: score
      };
    });

    ranking.sort((a, b) => b.score - a.score);

    res.json(ranking.slice(0, 20));

  } catch (error) {
    console.error('Post ranking error:', error);
    res.status(500).json({ error: '投稿ランキングの取得に失敗しました' });
  }
});
export default rankingRouter;