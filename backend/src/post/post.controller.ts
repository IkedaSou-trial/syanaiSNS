import * as express from 'express';
import prisma from '../lib/prisma';
import { authenticateJWT, AuthRequest, authenticateJWT_Optional } from '../auth/auth.middleware';
import { cloudinary } from '../lib/cloudinary'; // Cloudinaryを利用

const postRouter = express.Router();

// ハッシュタグ抽出用関数
const extractHashtags = (text: string): string[] => {
  if (!text) return [];
  const regex = /#([^#\s　]+)/g; 
  const matches = text.match(regex);
  if (!matches) return [];
  return [...new Set(matches.map(tag => tag.slice(1)))];
};

// 名前に店舗名をつける関数
const formatName = (user: any) => {
  if (user && user.store && user.store.name) {
    return `${user.displayName}＠${user.store.name}`;
  }
  return user ? user.displayName : '不明なユーザー';
};

/**
 * GET /posts
 */
postRouter.get('/', authenticateJWT_Optional, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  const { displayName, storeCode, keyword, startDate, endDate, onlyFollowing, category, filterType, tag } = req.query;

  try {
    const whereClause: any = {};
    const currentUserStoreCode = req.user?.storeCode;

    if (displayName) whereClause.author = { is: { displayName: { contains: String(displayName) } } };
    if (storeCode) whereClause.author = { is: { storeCode: { contains: String(storeCode) } } };
    if (keyword) whereClause.content = { contains: String(keyword) };
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
      whereClause.authorId = { in: follows.map(f => f.followingId) };
    }
    if (tag) whereClause.tags = { some: { name: String(tag) } };
    if (filterType === 'store' && currentUserStoreCode) {
      whereClause.AND = [{ author: { storeCode: currentUserStoreCode } }, { postType: 'STORE' }];
    }
    if (category) whereClause.category = String(category);

    const posts = await prisma.post.findMany({
      where: whereClause,
      orderBy: { createdAt: 'desc' },
      take: 20,
      include: {
        author: { include: { store: true } },
        likes: true, 
      },
    });

    const formattedPosts = posts.map(post => {
      const likeCount = post.likes.filter(l => l.type === 'LIKE').length;
      const copyCount = post.likes.filter(l => l.type === 'COPY').length;
      const isLikedByMe = userId ? post.likes.some(l => l.userId === userId && l.type === 'LIKE') : false;
      const isCopiedByMe = userId ? post.likes.some(l => l.userId === userId && l.type === 'COPY') : false;

      return {
        ...post,
        likeCount,
        copyCount,
        isLikedByMe,
        isCopiedByMe,
        isMine: String(userId) === String(post.authorId),
        author: {
          id: post.author.id,
          username: post.author.username,
          displayName: formatName(post.author),
          profileImageUrl: post.author.profileImageUrl,
          storeCode: post.author.storeCode,
        },
        likes: undefined,
      };
    });

    res.json(formattedPosts);

  } catch (error) {
    console.error('Get posts error:', error);
    res.status(500).json({ error: '取得に失敗しました' });
  }
});

/**
 * GET /ranking
 */
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
        author: { include: { store: true } },
        likes: true,
      },
    });

    const formattedPosts = posts.map(post => {
      const likeCount = post.likes.filter(l => l.type === 'LIKE').length;
      const copyCount = post.likes.filter(l => l.type === 'COPY').length;
      
      return {
        ...post,
        likeCount,
        copyCount,
        isLikedByMe: userId ? post.likes.some(l => l.userId === userId && l.type === 'LIKE') : false,
        isCopiedByMe: userId ? post.likes.some(l => l.userId === userId && l.type === 'COPY') : false,
        isMine: userId && post.authorId === userId,
        author: {
          id: post.author.id,
          username: post.author.username,
          displayName: formatName(post.author),
          profileImageUrl: post.author.profileImageUrl,
          storeCode: post.author.storeCode,
        },
        likes: undefined,
      };
    });

    res.json(formattedPosts);
  } catch (error) {
    console.error('Get ranking error:', error);
    res.status(500).json({ error: 'ランキングの取得に失敗しました' });
  }
});

/**
 * POST /posts/:id/reaction
 */
postRouter.post('/:id/reaction', authenticateJWT, async (req: AuthRequest, res) => {
  const { id } = req.params;
  const userId = req.user?.id;
  const { type } = req.body; 

  if (!userId) return res.status(403).json({ error: '認証が必要です' });
  if (!['LIKE', 'COPY'].includes(type)) return res.status(400).json({ error: '不正なタイプです' });

  try {
    const existing = await prisma.like.findUnique({
      where: {
        userId_postId_type: { userId, postId: id, type: type },
      },
    });

    if (existing) {
      await prisma.like.delete({ where: { id: existing.id } });
      res.json({ success: true, action: 'removed', type });
    } else {
      await prisma.like.create({
        data: { userId, postId: id, type },
      });
      res.json({ success: true, action: 'added', type });
    }
  } catch (error) {
    console.error('Reaction error:', error);
    res.status(500).json({ error: '操作に失敗しました' });
  }
});

/**
 * POST /posts
 * Cloudinary対応
 */
postRouter.post('/', authenticateJWT, async (req: AuthRequest, res: any) => {
  const { title, content, category, postType, imageBase64 } = req.body;
  const authorId = req.user?.id;

  if (!content) return res.status(400).json({ error: '投稿内容（content）は必須です。' });
  if (!authorId) return res.status(403).json({ error: '認証情報がありません。' });
  
  let imageUrl = null;

  try {
    // Cloudinaryへアップロード
    if (imageBase64 && imageBase64.startsWith('data:image')) {
      try {
        const uploadResponse = await cloudinary.uploader.upload(imageBase64, {
          folder: 'shainai_sns_posts', // フォルダ名
        });
        imageUrl = uploadResponse.secure_url;
      } catch (uploadError) {
        console.error('Cloudinary upload error:', uploadError);
        // 画像アップロード失敗しても投稿自体は成功させるならここでreturnしない
      }
    }

    const tagNames = extractHashtags(content);

    const newPost = await prisma.post.create({
      data: {
        title,
        content,
        authorId,
        imageUrl: imageUrl,
        category: category || 'その他',
        postType: postType || 'INDIVIDUAL',
        tags: {
          connectOrCreate: tagNames.map((tag) => ({
            where: { name: tag }, 
            create: { name: tag }, 
          })),
        },
      },
      include: {
        author: { include: { store: true } },
      },
    });

    res.status(201).json({
      ...newPost,
      isLikedByMe: false,
      isCopiedByMe: false,
      likeCount: 0,
      copyCount: 0,
      isMine: true,
      author: {
        id: newPost.author.id,
        username: newPost.author.username,
        displayName: formatName(newPost.author),
        profileImageUrl: newPost.author.profileImageUrl,
        storeCode: newPost.author.storeCode,
      },
    });
    
  } catch (error) {
    console.error('Error creating post:', error);
    res.status(500).json({ error: '投稿の作成に失敗しました。' });
  }
});

/**
 * PUT /posts/:id
 * Cloudinary対応
 */
postRouter.put('/:id', authenticateJWT, async (req: AuthRequest, res: any) => {
  const { id } = req.params;
  const { title, content, category, imageBase64 } = req.body; 
  const userId = req.user?.id;

  if (!content) return res.status(400).json({ error: '投稿内容（content）は必須です。' });
  if (!userId) return res.status(403).json({ error: '認証情報がありません。' });

  try {
    const existingPost = await prisma.post.findUnique({ where: { id } });

    if (!existingPost) return res.status(404).json({ error: '投稿が見つかりません' });
    if (existingPost.authorId !== userId) {
      return res.status(403).json({ error: '編集権限がありません' });
    }

    let imageUrl = existingPost.imageUrl;
    
    // 画像更新処理
    if (imageBase64 && imageBase64.startsWith('data:image')) {
      try {
        const uploadResponse = await cloudinary.uploader.upload(imageBase64, {
          folder: 'shainai_sns_posts',
        });
        imageUrl = uploadResponse.secure_url;
      } catch (uploadError) {
        console.error('Cloudinary upload error:', uploadError);
      }
    } else if (imageBase64 === null) {
      imageUrl = null; // 画像削除
    }

    const tagNames = extractHashtags(content);

    const updatedPost = await prisma.post.update({
      where: { id },
      data: {
        title,
        content,
        category: category || existingPost.category,
        imageUrl,
        tags: {
          set: [], 
          connectOrCreate: tagNames.map((tag) => ({
            where: { name: tag }, 
            create: { name: tag }, 
          })),
        },
      },
      include: {
        author: { include: { store: true } },
        tags: true,
      },
    });

    res.json(updatedPost);

  } catch (error) {
    console.error('Update post error:', error);
    res.status(500).json({ error: '更新に失敗しました' });
  }
});

/**
 * DELETE /posts/:id
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