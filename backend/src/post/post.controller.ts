import * as express from 'express';
import prisma from '../lib/prisma';
import { authenticateJWT, AuthRequest, authenticateJWT_Optional } from '../auth/auth.middleware';
import { PrismaClientKnownRequestError } from '@prisma/client/runtime/library';
import { upload } from '../lib/cloudinary';

const postRouter = express.Router();

/**
 * GET /posts
 * 投稿を一覧取得する (検索・絞り込み・ページネーション対応)
 */
postRouter.get('/', authenticateJWT_Optional, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  const { displayName, storeCode, keyword, startDate, endDate, onlyFollowing } = req.query;

  try {
    // --- 検索条件 (AND) を構築 ---
    const whereClause: any = {};

    // 1. 表示名検索
    if (displayName) {
      whereClause.author = {
        ...whereClause.author,
        displayName: { contains: String(displayName) },
      };
    }

    // 2. 店舗コード検索
    if (storeCode) {
      whereClause.author = {
        ...whereClause.author,
        storeCode: { contains: String(storeCode) },
      };
    }

    // 3. キーワード検索
    if (keyword) {
      whereClause.content = { contains: String(keyword) };
    }

    // 4. 日付・期間検索
    if (startDate) {
      const start = new Date(String(startDate));
      let end;
      if (endDate) {
        end = new Date(String(endDate));
      } else {
        end = new Date(String(startDate));
      }
      end.setHours(23, 59, 59, 999);

      whereClause.createdAt = {
        gte: start,
        lte: end,
      };
    }

    // 5. フォロー中のみフィルター
    if (onlyFollowing === 'true' && userId) {
      const follows = await prisma.follow.findMany({
        where: { followerId: userId },
        select: { followingId: true },
      });
      const followingIds = follows.map(f => f.followingId);
      whereClause.authorId = { in: followingIds };
    }

    // --- データ取得 ---
    const posts = await prisma.post.findMany({
      where: whereClause,
      orderBy: { createdAt: 'desc' },
      take: 20, // 件数制限 (重くならないように)
      include: {
        author: {
          select: {
            id: true,
            displayName: true,
            profileImageUrl: true,
            username: true,
            storeCode: true,
          },
        },
        _count: {
          select: { likes: true, comments: true },
        },
        likes: userId ? { where: { userId: userId }, select: { id: true } } : false,
      },
    });

    // --- 整形してレスポンス ---
    const postsWithLikeStatus = posts.map(post => ({
        ...post,
        isLikedByMe: !!(userId && post.likes && post.likes.length > 0),
        likeCount: post._count?.likes ?? 0,
        commentCount: post._count?.comments ?? 0,
        isMine: userId && post.authorId === userId,
        likes: undefined,
        _count: undefined,
    }));

    res.json(postsWithLikeStatus); // 🟢 ここで1回だけレスポンスする

  } catch (error) {
    console.error('Get posts error:', error);
    res.status(500).json({ error: '取得に失敗しました' });
  }
  // ❌ ここにあった「古いコード（重複していたtry...catch）」を削除しました
});

postRouter.get('/ranking', authenticateJWT_Optional, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  // type: 'weekly' | 'monthly'
  const { type } = req.query; 

  try {
    const now = new Date();
    let startDate = new Date();

    // 期間の設定
    if (type === 'monthly') {
      startDate.setDate(now.getDate() - 30); // 30日前
    } else {
      // デフォルトは週間 (7日前)
      startDate.setDate(now.getDate() - 7); 
    }

    const posts = await prisma.post.findMany({
      where: {
        createdAt: {
          gte: startDate, // startDate "以降" の投稿
        },
      },
      // 💡 いいねの数で降順ソート
      orderBy: {
        likes: {
          _count: 'desc',
        },
      },
      take: 20, // 上位20件を取得
      include: {
        author: {
          select: {
            id: true,
            displayName: true,
            profileImageUrl: true,
            username: true,
            storeCode: true,
          },
        },
        _count: {
          select: { likes: true, comments: true },
        },
        likes: userId ? { where: { userId: userId }, select: { id: true } } : false,
      },
    });

    // データ整形 (他のAPIと同じ)
    const formattedPosts = posts.map(post => ({
      ...post,
      isLikedByMe: !!(userId && post.likes && post.likes.length > 0),
      likeCount: post._count?.likes ?? 0,
      commentCount: post._count?.comments ?? 0,
      isMine: userId && post.authorId === userId,
      likes: undefined,
      _count: undefined,
    }));

    res.json(formattedPosts);

  } catch (error) {
    console.error('Get ranking error:', error);
    res.status(500).json({ error: 'ランキングの取得に失敗しました' });
  }
});

/**
 * POST /posts
 * 新しい投稿を作成する (画像アップロード対応)
 */
postRouter.post('/', authenticateJWT, upload.single('image'), async (req: any, res: any) => {
  const { title, content } = req.body;
  const authorId = req.user?.id;

  if (!content) {
    return res.status(400).json({ error: '投稿内容（content）は必須です。' });
  }
  
  if (!authorId) {
      return res.status(403).json({ error: '認証情報がありません。' });
  }
  
  const imageUrl = req.file ? req.file.path : null;

  try {
    const newPost = await prisma.post.create({
      data: {
        title,
        content,
        authorId,
        imageUrl: imageUrl,
      },
      include: {
        author: {
          select: {
            id: true,
            displayName: true,
            profileImageUrl: true,
            username: true,
            storeCode: true,
          },
        },
        _count: { select: { likes: true, comments: true } }
      },
    });

    const postWithLikeStatus = {
      ...newPost,
      isLikedByMe: false,
      likeCount: 0,
      commentCount: 0,
      isMine: true,
    };

    res.status(201).json(postWithLikeStatus);
    
  } catch (error) {
    console.error('Error creating post:', error);
    res.status(500).json({ error: '投稿の作成に失敗しました。' });
  }
});

/**
 * DELETE /posts/:id
 * 投稿を削除する
 */
postRouter.delete('/:id', authenticateJWT, async (req: AuthRequest, res) => {
  const { id } = req.params;
  const userId = req.user?.id;

  if (!userId) return res.status(403).json({ error: '認証が必要です' });

  try {
    const { count } = await prisma.post.deleteMany({
      where: {
        id: id,
        authorId: userId,
      },
    });

    if (count === 0) {
      return res.status(404).json({ error: '投稿が見つからないか、削除権限がありません' });
    }

    res.json({ message: '投稿を削除しました' });
  } catch (error) {
    console.error('Delete post error:', error);
    res.status(500).json({ error: '削除に失敗しました' });
  }
});

export default postRouter;