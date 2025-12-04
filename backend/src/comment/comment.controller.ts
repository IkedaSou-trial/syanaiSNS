import * as express from 'express';
import prisma from '../lib/prisma';
import { authenticateJWT, authenticateJWT_Optional, AuthRequest } from '../auth/auth.middleware';
import { PrismaClientKnownRequestError } from '@prisma/client/runtime/library';

const commentRouter = express.Router({ mergeParams: true });

/**
 * GET /posts/:postId/comments
 * 特定の投稿ID（postId）のコメント一覧を取得
 */
commentRouter.get('/', authenticateJWT_Optional, async (req: AuthRequest<{ postId: string }>, res) => {
  const { postId } = req.params;
  const userId = req.user?.id;

  try {
    const comments = await prisma.comment.findMany({
      where: {
        postId: postId,
      },
      orderBy: {
        createdAt: 'asc',
      },
      include: {
        author: {
          select: {
            id: true,
            displayName: true,
            profileImageUrl: true,
          },
        },
      },
    });

    // 自分のコメントかどうかのフラグ (isMine) を追加して返す
    const commentsWithStatus = comments.map(comment => ({
      ...comment,
      isMine: userId && comment.authorId === userId,
    }));

    res.json(commentsWithStatus);
  } catch (error) {
    console.error('Error fetching comments:', error);
    res.status(500).json({ error: 'コメントの取得に失敗しました。' });
  }
});

/**
 * POST /posts/:postId/comments
 * 特定の投稿ID（postId）にコメントを作成 (認証必須)
 */
commentRouter.post('/', authenticateJWT, async (req: AuthRequest<{ postId: string }>, res) => {
  const { postId } = req.params;
  const { content } = req.body;
  const authorId = req.user?.id;

  if (!content) {
    return res.status(400).json({ error: 'コメント内容（content）は必須です。' });
  }

  if (!authorId) {
    return res.status(403).json({ error: '認証情報がありません。' });
  }

  try {
    const newComment = await prisma.comment.create({
      data: {
        content,
        authorId,
        postId,
      },
      include: {
        author: {
          select: {
            id: true,
            displayName: true,
            profileImageUrl: true,
          },
        },
      },
    });
    
    // 作成直後のレスポンスにも isMine をつける
    const commentWithStatus = {
      ...newComment,
      isMine: true,
    };

    res.status(201).json(commentWithStatus);
  } catch (error) {
    console.error('Error creating comment:', error);
    if (error instanceof PrismaClientKnownRequestError) {
      if (error.code === 'P2003') {
        return res.status(404).json({ error: 'コメント対象の投稿が見つかりません。' });
      }
    }
    res.status(500).json({ error: 'コメントの作成に失敗しました。' });
  }
});

/**
 * DELETE /posts/:postId/comments/:commentId
 * コメントを削除する (本人のみ)
 */
commentRouter.delete('/:commentId', authenticateJWT, async (req: AuthRequest<{ postId: string; commentId: string }>, res) => {
  const { commentId } = req.params;
  const userId = req.user?.id;

  if (!userId) return res.status(403).json({ error: '認証が必要です' });

  try {
    const { count } = await prisma.comment.deleteMany({
      where: {
        id: commentId,
        authorId: userId, // 自分のコメントのみ削除可能
      },
    });

    if (count === 0) {
      return res.status(404).json({ error: 'コメントが見つからないか、削除権限がありません' });
    }

    res.json({ message: 'コメントを削除しました' });
  } catch (error) {
    console.error('Delete comment error:', error);
    res.status(500).json({ error: '削除に失敗しました' });
  }
});

export default commentRouter;