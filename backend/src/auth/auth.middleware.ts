import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { JWT_SECRET } from '../config'; // 👈 共通の設定ファイルを読み込む

export interface AuthRequest extends Request {
  user?: {
    id: string;
    username: string;
    storeCode?: string;
  };
}

export const authenticateJWT = (req: AuthRequest, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;

  if (authHeader) {
    const token = authHeader.split(' ')[1]; // "Bearer <token>" からトークンを取り出す

    jwt.verify(token, JWT_SECRET, (err: any, user: any) => {
      if (err) {
        // ▼▼▼ デバッグ用: エラーの詳細をログに出す ▼▼▼
        console.error("❌ JWT Verification Error:", err.message);
        // console.log("Received Token:", token); // 必要ならコメントアウトを外してトークンを確認
        
        return res.status(403).json({ error: "認証情報が無効です (トークン)" });
      }
      
      req.user = user;
      next();
    });
  } else {
    console.warn("⚠️ Authorization header missing");
    res.sendStatus(401);
  }
};

export const authenticateJWT_Optional = (req: AuthRequest, res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;

  if (authHeader) {
    const token = authHeader.split(' ')[1];

    jwt.verify(token, JWT_SECRET, (err: any, user: any) => {
      if (!err) {
        req.user = user;
      }
      next();
    });
  } else {
    next();
  }
};