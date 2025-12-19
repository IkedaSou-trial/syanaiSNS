import * as express from 'express';
import prisma from '../lib/prisma';
import { authenticateJWT, AuthRequest } from '../auth/auth.middleware';

const commentRouter = express.Router({ mergeParams: true }); 
// mergeParams: true にすることで、親ルーター(posts)の :postId を受け取れるようにする

/**
 * GET /posts/:postId/comments
 * コメント一覧取得
 */
// ▼▼▼ 修正: AuthRequest<any> ではなく AuthRequest にする ▼▼▼
commentRouter.get('/', authenticateJWT, async (req: AuthRequest, res) => {
  const { postId } = req.params;

  try {
    const comments = await prisma.comment.findMany({
      where: { postId: String(postId) },
      orderBy: { createdAt: 'asc' }, // 古い順
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
      },
    });

    const userId = req.user?.id;

    // 自分のコメントかどうか判定フラグをつける
    const formattedComments = comments.map((c) => ({
      ...c,
      isMyComment: c.authorId === userId,
    }));

    res.json(formattedComments);
  } catch (error) {
    console.error('Get comments error:', error);
    res.status(500).json({ error: 'コメントの取得に失敗しました' });
  }
});

/**
 * POST /posts/:postId/comments
 * コメント作成
 */
// ▼▼▼ 修正: AuthRequest<any> ではなく AuthRequest にする ▼▼▼
commentRouter.post('/', authenticateJWT, async (req: AuthRequest, res) => {
  const { postId } = req.params;
  const { content } = req.body;
  const authorId = req.user?.id;

  if (!content) {
    return res.status(400).json({ error: 'コメント内容を入力してください' });
  }
  if (!authorId) {
    return res.status(401).json({ error: '認証エラー' });
  }

  try {
    const newComment = await prisma.comment.create({
      data: {
        content,
        postId: String(postId),
        authorId: authorId,
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
      },
    });

    res.status(201).json({
      ...newComment,
      isMyComment: true,
    });
  } catch (error) {
    console.error('Create comment error:', error);
    res.status(500).json({ error: 'コメントの投稿に失敗しました' });
  }
});

/**
 * DELETE /posts/:postId/comments/:commentId
 * コメント削除
 */
// ▼▼▼ 修正: AuthRequest<any> ではなく AuthRequest にする ▼▼▼
commentRouter.delete('/:commentId', authenticateJWT, async (req: AuthRequest, res) => {
  const { commentId } = req.params;
  const userId = req.user?.id;

  try {
    const comment = await prisma.comment.findUnique({
      where: { id: String(commentId) },
    });

    if (!comment) {
      return res.status(404).json({ error: 'コメントが見つかりません' });
    }

    // 自分のコメントかチェック
    if (comment.authorId !== userId) {
      return res.status(403).json({ error: '削除権限がありません' });
    }

    await prisma.comment.delete({
      where: { id: String(commentId) },
    });

    res.json({ message: 'コメントを削除しました' });
  } catch (error) {
    console.error('Delete comment error:', error);
    res.status(500).json({ error: '削除に失敗しました' });
  }
});

export default commentRouter;