import * as express from 'express';
import prisma from '../lib/prisma';
import { authenticateJWT, AuthRequest } from '../auth/auth.middleware';
import { PrismaClientKnownRequestError } from '@prisma/client/runtime/library';

// We need mergeParams: true to get the :postId from the parent router
const likeRouter = express.Router({ mergeParams: true });

/**
 * POST /posts/:postId/like
 * 投稿に「いいね」する (認証必須)
 */
likeRouter.post('/', authenticateJWT, async (req: AuthRequest<{ postId: string }>, res) => {
  const { postId } = req.params;
  const userId = req.user?.id;

  if (!userId) {
    return res.status(403).json({ error: '認証情報がありません。' });
  }

  try {
    // Like.create を使って、いいねを作成
    // schema.prismaの @@unique([userId, postId]) 制約のおかげで、
    // 既にいいねしていた場合はエラーになる
    await prisma.like.create({
      data: {
        postId: postId,
        userId: userId,
      },
    });
    res.status(201).json({ message: 'いいねしました' });
  } catch (error) {
    if (error instanceof PrismaClientKnownRequestError) {
      // P2002: Unique constraint failed (既にいいねしている)
      if (error.code === 'P2002') {
        return res.status(409).json({ error: '既にいいねしています' });
      }
      // P2003: Foreign key constraint failed (投稿が存在しない)
      if (error.code === 'P2003') {
        return res.status(404).json({ error: '投稿が見つかりません' });
      }
    }
    console.error('Like error:', error);
    res.status(500).json({ error: 'いいねに失敗しました' });
  }
});

/**
 * DELETE /posts/:postId/like
 * 投稿の「いいね」を取り消す (認証必須)
 */
likeRouter.delete('/', authenticateJWT, async (req: AuthRequest<{ postId: string }>, res) => {
  const { postId } = req.params;
  const userId = req.user?.id;

  if (!userId) {
    return res.status(403).json({ error: '認証情報がありません。' });
  }

  try {
    // ユーザーIDと投稿IDの両方が一致する「いいね」を探して削除する
    // これにより、他人の「いいね」を削除できないようにする
    const { count } = await prisma.like.deleteMany({
      where: {
        postId: postId,
        userId: userId,
      },
    });

    if (count === 0) {
      // 削除対象が見つからなかった (そもそもいいねしていなかった)
      return res.status(404).json({ error: 'いいねが見つかりません' });
    }

    res.status(200).json({ message: 'いいねを取り消しました' });
  } catch (error) {
    console.error('Unlike error:', error);
    res.status(500).json({ error: 'いいねの取り消しに失敗しました' });
  }
});

export default likeRouter;