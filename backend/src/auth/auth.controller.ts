import * as express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import prisma from '../lib/prisma';
import { JWT_SECRET } from '../config';

const authRouter = express.Router();
const SALT_ROUNDS = 10;

// ▼▼▼ 共通: 名前に店舗名をつける関数 ▼▼▼
const formatName = (user: any) => {
  // 店舗情報(store)があり、かつ店舗名(store.name)がある場合
  if (user.store && user.store.name) {
    return `${user.displayName}＠${user.store.name}`;
  }
  // なければそのままの名前を返す
  return user.displayName;
};

// 共通のレスポンス生成
const createLoginResponse = (user: any) => {
  const token = jwt.sign(
    { 
      id: user.id,
      username: user.username,
      storeCode: user.storeCode
    },
    JWT_SECRET,
    { expiresIn: '30d' }
  );

  let categories = [];
  try {
    categories = JSON.parse(user.interestedCategories || '[]');
  } catch (e) {
    categories = [];
  }

  return {
    status: 'success',
    token,
    user: {
      id: user.id,
      username: user.username,
      // ▼▼▼ ここで関数を使って「＠店舗名」をつける ▼▼▼
      displayName: formatName(user), 
      storeCode: user.storeCode,
      profileImageUrl: user.profileImageUrl, // プロフィール画像も返しておく
      interestedCategories: categories,
    }
  };
};

/**
 * POST /auth/signup
 * 新規登録 API
 */
authRouter.post('/signup', async (req, res) => {
  const { username, password, displayName, storeCode } = req.body;

  if (!username || !password || !displayName) {
    return res.status(400).json({ error: '必須項目が不足しています' });
  }

  // パスワードの長さチェック
  if (password.length < 4) {
    return res.status(400).json({ error: 'パスワードは4文字以上で入力してください' });
  }

  try {
    // ユーザー重複チェック
    const existingUser = await prisma.user.findUnique({
      where: { username },
    });
    if (existingUser) {
      return res.status(409).json({ error: 'このIDは既に登録されています' });
    }

    // パスワードのハッシュ化
    const hashedPassword = await bcrypt.hash(password, SALT_ROUNDS);

    // ユーザー作成
    const user = await prisma.user.create({
      data: {
        username,
        password: hashedPassword,
        displayName,
        storeCode: storeCode || '000',
        interestedCategories: '[]',
      },
      // ▼▼▼ 店舗名を取得するために include を追加 ▼▼▼
      include: { store: true }, 
    });

    // そのままログインさせる
    res.status(201).json(createLoginResponse(user));

  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({ error: 'アカウント作成に失敗しました' });
  }
});

/**
 * POST /auth/login
 * 通常ログイン (ID + Password)
 */
authRouter.post('/login', async (req, res) => {
  const { username, password } = req.body;

  if (!username || !password) {
    return res.status(400).json({ error: 'IDとパスワードを入力してください' });
  }

  try {
    const user = await prisma.user.findUnique({
      where: { username },
      // ▼▼▼ 店舗名を取得するために include を追加 ▼▼▼
      include: { store: true }, 
    });

    if (!user) {
      return res.status(401).json({ error: 'ユーザーが見つかりません' });
    }

    // パスワード照合 (bcrypt)
    const isMatch = await bcrypt.compare(password, user.password);
    if (!isMatch) {
      return res.status(401).json({ error: 'パスワードが間違っています' });
    }

    res.json(createLoginResponse(user));

  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ error: 'ログインエラー' });
  }
});

/**
 * POST /auth/check-user
 * ユーザーが存在するかどうかだけを確認する
 */
authRouter.post('/check-user', async (req, res) => {
  const { username } = req.body;
  try {
    const user = await prisma.user.findUnique({ where: { username } });
    if (user) {
      res.json({ exists: true, username: user.username });
    } else {
      res.json({ exists: false, username });
    }
  } catch (error) {
    res.status(500).json({ error: '確認エラー' });
  }
});

export default authRouter;