import * as express from 'express';
import prisma from '../lib/prisma';
import { authenticateJWT, AuthRequest, authenticateJWT_Optional } from '../auth/auth.middleware';
import { cloudinary } from '../lib/cloudinary';

const userRouter = express.Router();

// ▼▼▼ 共通: 名前に店舗名をつける関数 ▼▼▼
const formatName = (user: any) => {
  if (user && user.store && user.store.name) {
    return `${user.displayName}＠${user.store.name}`;
  }
  return user ? user.displayName : '不明なユーザー';
};

/**
 * GET /users/:username
 * 指定したユーザー名のプロフィール情報を取得
 */
userRouter.get('/:username', authenticateJWT_Optional, async (req: AuthRequest, res) => {
  const { username } = req.params;
  const currentUserId = req.user?.id;

  try {
    const user = await prisma.user.findUnique({
      where: { username: username },
      // select ではなく include を使って全データ + store を取得
      include: {
        store: true, // 👈 店舗情報を取得
        _count: {
          select: { 
            posts: true,
            followedBy: true,
            following: true,
          },
        },
      },
    });

    if (!user) {
      return res.status(404).json({ error: 'ユーザーが見つかりません' });
    }

    // フォロー状態の判定
    let isFollowing = false;
    if (currentUserId) {
      const follow = await prisma.follow.findUnique({
        where: {
          followerId_followingId: {
            followerId: currentUserId, 
            followingId: user.id,
          },
        },
      });
      isFollowing = !!follow;
    }

    // ユーザーの投稿一覧
    const posts = await prisma.post.findMany({
      where: { authorId: user.id },
      orderBy: { createdAt: 'desc' },
      take: 20,
      include: {
        author: {
          include: { store: true },
        },
        // ▼▼▼ 修正: 全リアクションを取得 ▼▼▼
        likes: true, 
        tags: true, 
      },
    });

    const formattedPosts = posts.map(post => {
      // ▼▼▼ 修正: タイプ別にカウント ▼▼▼
      const likeCount = post.likes.filter(l => l.type === 'LIKE').length;
      const copyCount = post.likes.filter(l => l.type === 'COPY').length;
      
      return {
        ...post,
        likeCount,
        copyCount,
        isLikedByMe: currentUserId ? post.likes.some(l => l.userId === currentUserId && l.type === 'LIKE') : false,
        isCopiedByMe: currentUserId ? post.likes.some(l => l.userId === currentUserId && l.type === 'COPY') : false,
        isMine: currentUserId === post.authorId,
        author: {
          id: post.author.id,
          username: post.author.username,
          displayName: formatName(post.author),
          profileImageUrl: post.author.profileImageUrl,
          storeCode: post.author.storeCode,
        },
        likes: undefined, // 生データ削除
      };
    });

    let categories = [];
    try {
      categories = JSON.parse(user.interestedCategories || '[]');
    } catch (e) {
      categories = [];
    }

    res.json({
      user: {
        id: user.id,
        username: user.username,
        displayName: formatName(user), 
        storeCode: user.storeCode,
        profileImageUrl: user.profileImageUrl,
        interestedCategories: categories,
        createdAt: user.createdAt,
        postCount: user._count.posts,
        followerCount: user._count.followedBy,
        followingCount: user._count.following,
        _count: undefined,
        isMe: currentUserId === user.id,
        isFollowing: isFollowing,
      },
      posts: formattedPosts,
    });

  } catch (error) {
    console.error('Get user profile error:', error);
    res.status(500).json({ error: 'プロフィールの取得に失敗しました' });
  }
});

/**
 * GET /users/:username/following
 * フォロー中のユーザー一覧
 */
userRouter.get('/:username/following', authenticateJWT_Optional, async (req: AuthRequest, res) => {
  const { username } = req.params;
  try {
    const user = await prisma.user.findUnique({ where: { username: username } });
    if (!user) return res.status(404).json({ error: 'ユーザーが見つかりません' });

    const following = await prisma.follow.findMany({
      where: { followerId: user.id },
      include: {
        following: { include: { store: true } },
      },
    });

    const users = following.map(f => ({
      id: f.following.id,
      username: f.following.username,
      displayName: formatName(f.following),
      profileImageUrl: f.following.profileImageUrl,
      storeCode: f.following.storeCode,
    }));
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: 'リストの取得に失敗しました' });
  }
});

/**
 * PUT /users/me
 * プロフィール更新
 */
userRouter.put('/me', authenticateJWT, async (req: AuthRequest, res) => {
  const { displayName, profileImageBase64, storeCode } = req.body;
  const userId = req.user?.id;

  if (!userId) return res.status(403).json({ error: '認証が必要です' });

  try {
    let profileImageUrl: string | undefined;
    if (profileImageBase64 && profileImageBase64.startsWith('data:image')) {
      try {
        const uploadResponse = await cloudinary.uploader.upload(profileImageBase64, {
          folder: 'shainai_sns_profiles',
          transformation: [{ width: 400, height: 400, crop: 'fill' }],
        });
        profileImageUrl = uploadResponse.secure_url;
      } catch (uploadError) {
        console.error('Cloudinary upload error:', uploadError);
      }
    }

    const updateData: any = {
      displayName,
    };
    if (profileImageUrl) {
      updateData.profileImageUrl = profileImageUrl;
    }
    if (storeCode !== undefined) {
      updateData.storeCode = storeCode;
    }

    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: updateData,
      // ▼▼▼ store: true を追加 ▼▼▼
      include: { store: true }, 
    });
    
    // レスポンス用のデータ整形
    const responseUser = {
        id: updatedUser.id,
        username: updatedUser.username,
        displayName: formatName(updatedUser), // 名前加工
        profileImageUrl: updatedUser.profileImageUrl,
        storeCode: updatedUser.storeCode,
    };

    res.json({ message: 'プロフィールを更新しました', user: responseUser });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'プロフィールの更新に失敗しました' });
  }
});

/**
 * PUT /users/:id/categories
 * カテゴリー更新
 */
userRouter.put('/:id/categories', authenticateJWT, async (req: AuthRequest, res) => {
  const targetUserId = req.params.id;
  const currentUserId = req.user?.id;

  if (!currentUserId || targetUserId !== currentUserId) {
    return res.status(403).json({ error: '権限がありません' });
  }

  const { categories } = req.body; 

  if (!Array.isArray(categories)) {
    return res.status(400).json({ error: 'カテゴリーはリスト形式で送信してください' });
  }

  try {
    const updatedUser = await prisma.user.update({
      where: { id: currentUserId },
      data: {
        interestedCategories: JSON.stringify(categories),
      },
    });

    res.json({ 
      status: 'success', 
      interestedCategories: JSON.parse(updatedUser.interestedCategories || '[]') 
    });
  } catch (error) {
    console.error('Update categories error:', error);
    res.status(500).json({ error: 'カテゴリーの更新に失敗しました' });
  }
});

/**
 * GET /users/me/copied
 * 自分が「真似したい」した投稿一覧を取得
 */
userRouter.get('/me/copied', authenticateJWT, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  if (!userId) return res.status(403).json({ error: '認証が必要です' });

  try {
    // Likeテーブルから type='COPY' のものを取得し、関連するPostデータも引く
    const likes = await prisma.like.findMany({
      where: {
        userId: userId,
        type: 'COPY',
      },
      include: {
        post: {
          include: {
            author: { include: { store: true } },
            likes: true, // リアクション状態表示用
            tags: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' }, // 最近保存したもの順
    });

    // 投稿データの形式を整形
    const formattedPosts = likes.map(like => {
      const post = like.post;
      // 削除された投稿などがnullでないか確認（通常は外部キー制約で消えるが念のため）
      if (!post) return null;

      const likeCount = post.likes.filter(l => l.type === 'LIKE').length;
      const copyCount = post.likes.filter(l => l.type === 'COPY').length;

      return {
        ...post,
        likeCount,
        copyCount,
        isLikedByMe: post.likes.some(l => l.userId === userId && l.type === 'LIKE'),
        isCopiedByMe: true, // ここにあるということは必ずON
        isMine: post.authorId === userId,
        author: {
          id: post.author.id,
          username: post.author.username,
          displayName: formatName(post.author),
          profileImageUrl: post.author.profileImageUrl,
          storeCode: post.author.storeCode,
        },
        likes: undefined,
      };
    }).filter(p => p !== null); // nullを除外

    res.json(formattedPosts);

  } catch (error) {
    console.error('Get copied posts error:', error);
    res.status(500).json({ error: 'リストの取得に失敗しました' });
  }
});

/**
 * POST /users/:userId/follow
 */
userRouter.post('/:userId/follow', authenticateJWT, async (req: AuthRequest, res) => {
  const targetUserId = req.params.userId;
  const currentUserId = req.user?.id;

  if (!currentUserId) return res.status(401).json({ error: '認証が必要です' });
  if (targetUserId === currentUserId) return res.status(400).json({ error: '自分自身はフォローできません' });

  try {
    const targetUser = await prisma.user.findUnique({ where: { id: targetUserId } });
    if (!targetUser) return res.status(404).json({ error: 'ユーザーが見つかりません' });

    const existingFollow = await prisma.follow.findUnique({
      where: {
        followerId_followingId: {
          followerId: currentUserId,
          followingId: targetUserId,
        },
      },
    });

    if (existingFollow) return res.status(409).json({ error: '既にフォローしています' });

    await prisma.follow.create({
      data: {
        followerId: currentUserId,
        followingId: targetUserId,
      },
    });

    res.status(201).json({ message: 'フォローしました' });
  } catch (error) {
    console.error('Follow error:', error);
    res.status(500).json({ error: 'フォローに失敗しました' });
  }
});

/**
 * DELETE /users/:userId/follow
 */
userRouter.delete('/:userId/follow', authenticateJWT, async (req: AuthRequest, res) => {
  const targetUserId = req.params.userId;
  const currentUserId = req.user?.id;

  if (!currentUserId) return res.status(401).json({ error: '認証が必要です' });

  try {
    const follow = await prisma.follow.findUnique({
      where: {
        followerId_followingId: {
          followerId: currentUserId,
          followingId: targetUserId,
        },
      },
    });

    if (!follow) return res.status(404).json({ error: 'フォローしていません' });

    await prisma.follow.delete({
      where: {
        followerId_followingId: {
          followerId: currentUserId,
          followingId: targetUserId,
        },
      },
    });

    res.json({ message: 'フォロー解除しました' });
  } catch (error) {
    console.error('Unfollow error:', error);
    res.status(500).json({ error: 'フォロー解除に失敗しました' });
  }
});

export default userRouter;