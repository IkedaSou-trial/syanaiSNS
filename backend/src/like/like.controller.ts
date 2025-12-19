import * as express from 'express';
import prisma from '../lib/prisma';
import { authenticateJWT, AuthRequest } from '../auth/auth.middleware';

const likeRouter = express.Router({ mergeParams: true });

/**
 * POST /posts/:postId/like
 * いいねを追加
 */
// ▼▼▼ 修正: AuthRequest<any> ではなく AuthRequest にする ▼▼▼
likeRouter.post('/', authenticateJWT, async (req: AuthRequest, res) => {
  const { postId } = req.params;
  const userId = req.user?.id;

  if (!userId) {
    return res.status(401).json({ error: '認証が必要です' });
  }

  try {
    // 既にいいねしているかチェック
    const existingLike = await prisma.like.findFirst({
      where: {
        postId: String(postId),
        userId: userId,
      },
    });

    if (existingLike) {
      return res.status(409).json({ error: '既にいいねしています' });
    }

    await prisma.like.create({
      data: {
        postId: String(postId),
        userId: userId,
      },
    });

    res.status(201).json({ message: 'いいねしました' });
  } catch (error) {
    console.error('Like error:', error);
    res.status(500).json({ error: 'いいねに失敗しました' });
  }
});

/**
 * DELETE /posts/:postId/like
 * いい上げ解除
 */
// ▼▼▼ 修正: AuthRequest<any> ではなく AuthRequest にする ▼▼▼
likeRouter.delete('/', authenticateJWT, async (req: AuthRequest, res) => {
  const { postId } = req.params;
  const userId = req.user?.id;

  if (!userId) {
    return res.status(401).json({ error: '認証が必要です' });
  }

  try {
    const existingLike = await prisma.like.findFirst({
      where: {
        postId: String(postId),
        userId: userId,
      },
    });

    if (!existingLike) {
      return res.status(404).json({ error: 'いいねが見つかりません' });
    }

    await prisma.like.delete({
      where: {
        id: existingLike.id,
      },
    });

    res.json({ message: 'いいねを解除しました' });
  } catch (error) {
    console.error('Unlike error:', error);
    res.status(500).json({ error: 'いいね解除に失敗しました' });
  }
});

export default likeRouter;