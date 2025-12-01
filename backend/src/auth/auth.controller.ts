import * as express from 'express';
import bcrypt from 'bcryptjs'; // 'bcrypt' を 'bcryptjs' に変更
import jwt from 'jsonwebtoken';
import prisma from '../lib/prisma'; // 修正: lib/prisma.tsからのインポート
import { PrismaClientKnownRequestError } from '@prisma/client/runtime/library';

const authRouter = express.Router();
const SALT_ROUNDS = 10;
// 💡 注意: 本番環境では .env などで管理してください
const JWT_SECRET = process.env.JWT_SECRET || 'YOUR_SUPER_SECRET_KEY'; 

/**
 * POST /signup: 新規ユーザーアカウントの作成
 */
authRouter.post('/signup', async (req, res) => {
  const { username, password, displayName, storeCode } = req.body;

  if (!username || !password || !displayName || !storeCode) {
    return res.status(400).json({ error: '全ての必須フィールドを入力してください。' });
  }

  try {
    const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);

    const user = await prisma.user.create({
      data: {
        username,
        password: hashedPassword,
        displayName,
        storeCode,
      },
      select: {
        id: true,
        username: true,
        displayName: true,
        storeCode: true,
        createdAt: true,
      },
    });

    res.status(201).json({ message: 'アカウントが正常に作成されました', user });
  } catch (error) {
    if (error instanceof PrismaClientKnownRequestError) {
        if (error.code === 'P2002') {
        return res.status(409).json({ error: 'このユーザー名はすでに使用されています。' });
        }
        console.error('Signup error:', error);
        res.status(500).json({ error: 'サーバーエラーによりアカウント作成に失敗しました。' });
    }
  }
});

/**
 * POST /login: ユーザーのログインとJWTの発行
 */
authRouter.post('/login', async (req, res) => {
  const { username, password } = req.body;
  console.log(`[AUTH] /login 試行: ${username}`); // ログ1

  if (!username || !password) {
    console.log('[AUTH] ユーザー名またはパスワードがありません');
    return res.status(400).json({ error: 'ユーザー名とパスワードを入力してください。' });
  }

  try {
    console.log('[AUTH] データベースでユーザーを検索中...');
    const user = await prisma.user.findUnique({
      where: { username },
    });
    console.log('[AUTH] データベース検索完了。'); // ログ2 (prisma:queryの直後に出るはず)

    if (!user) {
      console.log('[AUTH] ユーザーが見つかりません。');
      return res.status(401).json({ error: '無効なユーザー名またはパスワードです。' });
    }

    console.log(`[AUTH] ユーザー発見: ${user.username}`);
    
    console.log('[AUTH] パスワードを比較中...');
    const isValid = await bcrypt.compare(password, user.password);
    console.log(`[AUTH] パスワード比較完了。結果: ${isValid}`);


    if (!isValid) {
      console.log('[AUTH] パスワードが無効です。');
      return res.status(401).json({ error: '無効なユーザー名またはパスワードです。' });
    }

    console.log('[AUTH] パスワード有効。JWTを生成中...'); // ログ3
    const token = jwt.sign(
      { userId: user.id, username: user.username },
      JWT_SECRET,
      { expiresIn: '1d' }
    );

    console.log('[AUTH] JWT生成完了。レスポンスを送信します。'); // ログ4
    res.json({ 
      message: 'ログイン成功 (デバッグ)', 
      token,
      user: {
        id: user.id,
        username: user.username,
        displayName: user.displayName,
      }
    });
  } catch (error) {
    console.error('[AUTH] /login の catch ブロックでエラー:', error);
    res.status(500).json({ error: 'サーバーエラーによりログインに失敗しました。' });
  }
});

export default authRouter;