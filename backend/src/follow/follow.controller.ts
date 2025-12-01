import * as express from 'express';
import prisma from '../lib/prisma';
import { authenticateJWT, AuthRequest } from '../auth/auth.middleware';
import { PrismaClientKnownRequestError } from '@prisma/client/runtime/library';

const followRouter = express.Router();

/**
 * POST /users/:userId/follow
 * 指定したユーザーをフォローする
 */
followRouter.post('/:userId/follow', authenticateJWT, async (req: AuthRequest, res) => {
  const targetUserId = req.params.userId; // フォロー相手のID
  const currentUserId = req.user?.id;     // 自分のID

  if (!currentUserId) return res.status(403).json({ error: '認証が必要です' });
  if (targetUserId === currentUserId) {
    return res.status(400).json({ error: '自分自身はフォローできません' });
  }

  try {
    await prisma.follow.create({
      data: {
        followerId: currentUserId,
        followingId: targetUserId,
      },
    });
    res.status(201).json({ message: 'フォローしました' });
  } catch (error) {
    if (error instanceof PrismaClientKnownRequestError && error.code === 'P2002') {
      return res.status(409).json({ error: '既にフォローしています' });
    }
    console.error('Follow error:', error);
    res.status(500).json({ error: 'フォローに失敗しました' });
  }
});

/**
 * DELETE /users/:userId/follow
 * フォローを解除する
 */
followRouter.delete('/:userId/follow', authenticateJWT, async (req: AuthRequest, res) => {
  const targetUserId = req.params.userId;
  const currentUserId = req.user?.id;

  if (!currentUserId) return res.status(403).json({ error: '認証が必要です' });

  try {
    await prisma.follow.delete({
      where: {
        followerId_followingId: {
          followerId: currentUserId,
          followingId: targetUserId,
        },
      },
    });
    res.json({ message: 'フォローを解除しました' });
  } catch (error) {
    // 既に解除されている場合などはエラーにせず成功扱いでも良いが、今回はログのみ
    console.error('Unfollow error:', error);
    res.status(500).json({ error: 'フォロー解除に失敗しました' });
  }
});

export default followRouter;