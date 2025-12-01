import { Request, Response, NextFunction } from 'express';
import { ParamsDictionary } from 'express-serve-static-core'; 
import { ParsedQs } from 'qs'; 
import jwt from 'jsonwebtoken';
import prisma from '../lib/prisma';

// ExpressのRequestインターフェースを拡張し、userプロパティを持てるようにする
// これにより、以降の処理で req.user が型安全に参照できる

// 💡 注意: 認証コントローラーと同じシークレットキーを使用
const JWT_SECRET = process.env.JWT_SECRET || 'YOUR_SUPER_SECRET_KEY';

export interface AuthRequest<P = ParamsDictionary> extends Request<P> {
  user?: {
    id: string;
    username: string;
  };
}

/**
 * 認証ミドルウェア
 * リクエストヘッダーのAuthorizationからJWTを検証する
 */
export const authenticateJWT = async (
  req: AuthRequest, // 💡 AuthRequest を使用
  res: Response, 
  next: NextFunction
) => {
  const authHeader = req.headers.authorization;

  if (authHeader) {
    const token = authHeader.split(' ')[1]; // "Bearer TOKEN" から TOKEN を取得
    
    try {
      // JWTを検証
      const decoded = jwt.verify(token, JWT_SECRET) as { userId: string; username: string };
      
      // データベースからユーザー情報を取得 (ユーザーが存在するか確認)
      const user = await prisma.user.findUnique({
        where: { id: decoded.userId },
        select: { id: true, username: true } // 必要な情報だけを選択
      });

      if (user) {
        req.user = user; // ユーザー情報をリクエストオブジェクトにアタッチ
        next(); // 次のミドルウェアまたはルートハンドラへ
      } else {
        res.status(401).json({ error: '認証情報が無効です (ユーザー見つからず)' });
      }
    } catch (err) {
      // トークンが無効または期限切れの場合
      res.status(403).json({ error: '認証情報が無効です (トークン)' });
    }
  } else {
    // Authorization ヘッダーがない場合
    res.status(401).json({ error: '認証情報がありません。' });
  }
};

/**
 * 認証ミドルウェア (オプショナル)
 * トークンがあれば検証し、なければスルーする
 */
export const authenticateJWT_Optional = async (
  req: AuthRequest, // 💡 AuthRequest を使用
  res: Response, 
  next: NextFunction
) => {
  const authHeader = req.headers.authorization;

  if (authHeader) {
    const token = authHeader.split(' ')[1];
    if (token) {
      try {
        const decoded = jwt.verify(token, JWT_SECRET) as { userId: string; username: string };
        const user = await prisma.user.findUnique({
          where: { id: decoded.userId },
          select: { id: true, username: true }
        });
        
        if (user) {
          req.user = user; // ユーザー情報をアタッチ
        }
      } catch (err) {
        // トークンが無効でもエラーにはせず、そのまま次へ
        // console.warn('Optional JWT authentication failed but continuing:', err);
      }
    }
  }
  next(); // 認証があってもなくても、次の処理へ進む
};