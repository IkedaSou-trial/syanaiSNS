import * as express from 'express';
import prisma from '../lib/prisma';
import { authenticateJWT, AuthRequest, authenticateJWT_Optional } from '../auth/auth.middleware';
import cloudinary from '../lib/cloudinary'; // 💡 追加: 画像アップロード用

const userRouter = express.Router();

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
      select: {
        id: true,
        username: true,
        displayName: true,
        storeCode: true,
        profileImageUrl: true,
        createdAt: true,
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

    // ユーザーの投稿一覧も取得 (最新20件)
    const posts = await prisma.post.findMany({
      where: { authorId: user.id },
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
        likes: currentUserId ? { where: { userId: currentUserId }, select: { id: true } } : false,
      },
    });

    const formattedPosts = posts.map(post => ({
      ...post,
      isLikedByMe: !!(currentUserId && post.likes && post.likes.length > 0),
      likeCount: post._count?.likes ?? 0,
      commentCount: post._count?.comments ?? 0,
      isMine: currentUserId === post.authorId,
      likes: undefined,
      _count: undefined,
    }));

    res.json({
      user: {
        ...user,
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
 * 指定したユーザーがフォローしているユーザー一覧を取得
 */
userRouter.get('/:username/following', authenticateJWT_Optional, async (req: AuthRequest, res) => {
  const { username } = req.params;

  try {
    const user = await prisma.user.findUnique({
      where: { username: username },
    });

    if (!user) return res.status(404).json({ error: 'ユーザーが見つかりません' });

    const following = await prisma.follow.findMany({
      where: { followerId: user.id },
      include: {
        following: { 
          select: {
            id: true,
            username: true,
            displayName: true,
            profileImageUrl: true,
            storeCode: true,
          },
        },
      },
    });

    const users = following.map(f => f.following);
    res.json(users);
  } catch (error) {
    console.error('Get following list error:', error);
    res.status(500).json({ error: 'リストの取得に失敗しました' });
  }
});

/**
 * PUT /users/me
 * 自分のプロフィール情報を更新 (Cloudinary対応版)
 */
userRouter.put('/me', authenticateJWT, async (req: AuthRequest, res) => {
  const userId = req.user?.id;
  const { displayName, profileImageBase64, storeCode } = req.body;

  if (!userId) return res.status(403).json({ error: '認証が必要です' });

  try {
    let profileImageUrl: string | undefined;

    // 💡 修正: 画像データ(Base64)がある場合、Cloudinaryにアップロードする
    if (profileImageBase64 && profileImageBase64.startsWith('data:image')) {
      try {
        const uploadResponse = await cloudinary.uploader.upload(profileImageBase64, {
          folder: 'shainai_sns_profiles', // Cloudinary上のフォルダ名
          transformation: [
            { width: 400, height: 400, crop: 'fill' } // 正方形に自動トリミング
          ],
        });
        // アップロード後のURLを取得
        profileImageUrl = uploadResponse.secure_url;
      } catch (uploadError) {
        console.error('Cloudinary upload error:', uploadError);
        return res.status(500).json({ error: '画像のアップロードに失敗しました' });
      }
    }

    // データベースを更新
    const updatedUser = await prisma.user.update({
      where: { id: userId },
      data: {
        displayName: displayName,
        // 新しい画像URLがあれば更新、なければ何もしない(undefined)
        profileImageUrl: profileImageUrl, 
        storeCode: storeCode || undefined,
      },
      select: {
        id: true,
        username: true,
        displayName: true,
        profileImageUrl: true,
      },
    });

    res.json({ message: 'プロフィールを更新しました', user: updatedUser });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'プロフィールの更新に失敗しました' });
  }
});

export default userRouter;