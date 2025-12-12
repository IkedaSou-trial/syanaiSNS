import * as express from 'express';
import prisma from '../lib/prisma';
import { authenticateJWT, AuthRequest, authenticateJWT_Optional } from '../auth/auth.middleware';
import { upload } from '../lib/cloudinary';

const postRouter = express.Router();

/**
 * GET /posts
 */
postRouter.get('/', authenticateJWT_Optional, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  // category を追加
  const { displayName, storeCode, keyword, startDate, endDate, onlyFollowing, category } = req.query;

  try {
    const whereClause: any = {};

    if (displayName) {
      whereClause.author = { ...whereClause.author, displayName: { contains: String(displayName) } };
    }
    if (storeCode) {
      whereClause.author = { ...whereClause.author, storeCode: { contains: String(storeCode) } };
    }
    if (keyword) {
      whereClause.content = { contains: String(keyword) };
    }
    if (startDate) {
      const start = new Date(String(startDate));
      let end = endDate ? new Date(String(endDate)) : new Date(String(startDate));
      end.setHours(23, 59, 59, 999);
      whereClause.createdAt = { gte: start, lte: end };
    }
    if (onlyFollowing === 'true' && userId) {
      const follows = await prisma.follow.findMany({
        where: { followerId: userId },
        select: { followingId: true },
      });
      const followingIds = follows.map(f => f.followingId);
      whereClause.authorId = { in: followingIds };
    }
    
    // カテゴリー検索
    if (category) {
      whereClause.category = String(category);
    }

    const posts = await prisma.post.findMany({
      where: whereClause,
      orderBy: { createdAt: 'desc' },
      take: 20,
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
        _count: { select: { likes: true, comments: true } },
        likes: userId ? { where: { userId: userId }, select: { id: true } } : false,
      },
    });

    const postsWithLikeStatus = posts.map(post => ({
        ...post,
        isLikedByMe: !!(userId && post.likes && post.likes.length > 0),
        likeCount: post._count?.likes ?? 0,
        commentCount: post._count?.comments ?? 0,
        isMine: userId && post.authorId === userId,
        likes: undefined,
        _count: undefined,
    }));

    res.json(postsWithLikeStatus);

  } catch (error) {
    console.error('Get posts error:', error);
    res.status(500).json({ error: '取得に失敗しました' });
  }
});

// GET /ranking (変更なし、ID文字列対応済み)
postRouter.get('/ranking', authenticateJWT_Optional, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  const { type } = req.query; 

  try {
    const now = new Date();
    let startDate = new Date();
    if (type === 'monthly') startDate.setDate(now.getDate() - 30);
    else startDate.setDate(now.getDate() - 7); 

    const posts = await prisma.post.findMany({
      where: { createdAt: { gte: startDate } },
      orderBy: { likes: { _count: 'desc' } },
      take: 20,
      include: {
        author: {
          select: { id: true, displayName: true, profileImageUrl: true, username: true, storeCode: true },
        },
        _count: { select: { likes: true, comments: true } },
        likes: userId ? { where: { userId: userId }, select: { id: true } } : false,
      },
    });

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
 */
postRouter.post('/', authenticateJWT, upload.single('image'), async (req: any, res: any) => {
  // categoryを追加
  const { title, content, category } = req.body;
  const authorId = req.user?.id;

  if (!content) return res.status(400).json({ error: '投稿内容（content）は必須です。' });
  if (!authorId) return res.status(403).json({ error: '認証情報がありません。' });
  
  const imageUrl = req.file ? req.file.path : null;

  try {
    const newPost = await prisma.post.create({
      data: {
        title,
        content,
        authorId,
        imageUrl: imageUrl,
        category: category || 'その他', // カテゴリー保存
      },
      include: {
        author: {
          select: { id: true, displayName: true, profileImageUrl: true, username: true, storeCode: true },
        },
        _count: { select: { likes: true, comments: true } }
      },
    });

    res.status(201).json({
      ...newPost,
      isLikedByMe: false,
      likeCount: 0,
      commentCount: 0,
      isMine: true,
    });
    
  } catch (error) {
    console.error('Error creating post:', error);
    res.status(500).json({ error: '投稿の作成に失敗しました。' });
  }
});

/**
 * DELETE /posts/:id
 */
postRouter.delete('/:id', authenticateJWT, async (req: AuthRequest, res) => {
  const { id } = req.params; // 文字列
  const userId = req.user?.id; // 文字列

  if (!userId) return res.status(403).json({ error: '認証が必要です' });

  try {
    const { count } = await prisma.post.deleteMany({
      where: {
        id: id,       // 文字列のまま渡す
        authorId: userId, // 文字列のまま渡す
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