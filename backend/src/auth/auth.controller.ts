import * as express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import axios from 'axios';
import prisma from '../lib/prisma';
import * as crypto from 'crypto';

const authRouter = express.Router();
const SALT_ROUNDS = 10;
const JWT_SECRET = process.env.JWT_SECRET || 'YOUR_SUPER_SECRET_KEY';

// 共通のログイン成功レスポンス生成関数
const createLoginResponse = (user: any) => {
  const token = jwt.sign(
    { userId: user.id, username: user.username },
    JWT_SECRET,
    { expiresIn: '30d' }
  );

  // JSON文字列を配列に戻す
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
      displayName: user.displayName,
      storeCode: user.storeCode,
      interestedCategories: categories, // 👈 追加
    }
  };
};

async function callExternalAuthApi(account: string, passwordHash: string) {
  console.log(`[AUTH] 外部APIへ問い合わせ: ${account}`);
  try {
    const response = await axios.post('http://auth-intra.trechina.cn/Apps/authentication/authenticate', {
      account: account,
      password: passwordHash, 
      systemid: "7c095dc3-6bea-4636-bacc-ce9abb19b597",
      clientid: "10745145"
    }, {
      headers: { 'Content-Type': 'application/json' }
    });
    return response.data;
  } catch (error) {
    console.error('External API Error:', error);
    return null;
  }
}

// ... (以下、前回と同じ POST /login/barcode と POST /login のロジック)
// 上記の createLoginResponse 関数を使っていればOKです。
// 必要なら前回のコードをここに貼り付けますが、変更点は createLoginResponse だけです。

authRouter.post('/login/barcode', async (req, res) => {
  const { barcode } = req.body;
  if (!barcode) return res.status(400).json({ error: 'バーコードなし' });

  try {
    let user = await prisma.user.findUnique({ where: { username: barcode } });
    if (user) return res.json(createLoginResponse(user));

    const defaultApiHash = "670b14728ad9902aecba32e22fa4f6bd";
    const authData = await callExternalAuthApi(barcode, defaultApiHash);

    if (!authData || authData.successed !== "0" || !authData.user) {
      return res.status(401).json({ error: '社員情報の取得失敗' });
    }

    const externalUser = authData.user;
    const orgCode = externalUser.jobs?.[0]?.orgcode || '000';
    const dummyHash = await bcrypt.hash("000000", SALT_ROUNDS);

    user = await prisma.user.create({
      data: {
        username: externalUser.account,
        password: dummyHash,
        displayName: externalUser.name,
        storeCode: orgCode,
      },
    });

    return res.json(createLoginResponse(user));

  } catch (error) {
    console.error('Barcode login error:', error);
    res.status(500).json({ error: 'Server Error' });
  }
});

authRouter.post('/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) return res.status(400).json({ error: '入力不足' });

  try {
    const inputHash = crypto.createHash('md5').update(password).digest('hex');
    const authData = await callExternalAuthApi(username, inputHash);

    if (!authData || authData.successed !== "0" || !authData.user) {
      return res.status(401).json({ error: '認証失敗' });
    }

    const externalUser = authData.user;
    const orgCode = externalUser.jobs?.[0]?.orgcode || '000';
    
    let user = await prisma.user.findUnique({ where: { username } });

    if (user) {
      user = await prisma.user.update({
        where: { id: user.id },
        data: { displayName: externalUser.name, storeCode: orgCode }
      });
    } else {
      const dummyHash = await bcrypt.hash("000000", SALT_ROUNDS);
      user = await prisma.user.create({
        data: {
          username: externalUser.account,
          password: dummyHash,
          displayName: externalUser.name,
          storeCode: orgCode,
        },
      });
    }

    return res.json(createLoginResponse(user));

  } catch (error) {
    console.error('Manual login error:', error);
    res.status(500).json({ error: 'Server Error' });
  }
});

export default authRouter;