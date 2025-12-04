import * as express from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import axios from 'axios'; // 💡 追加: 外部API通信用
import prisma from '../lib/prisma';

const authRouter = express.Router();
const SALT_ROUNDS = 10;
const JWT_SECRET = process.env.JWT_SECRET || 'YOUR_SUPER_SECRET_KEY';

/**
 * POST /login/barcode
 * 1. バーコード番号で外部認証サーバーに問い合わせ
 * 2. 成功したらその情報でアプリ内にユーザーを作成or特定
 * 3. アプリ用JWTを発行
 */
authRouter.post('/login/barcode', async (req, res) => {
  const { barcode } = req.body;

  if (!barcode) {
    return res.status(400).json({ error: 'バーコードが読み取れませんでした。' });
  }

  try {
    console.log(`[AUTH] 外部認証APIへ問い合わせ: ${barcode}`);

    // 1. 外部認証APIを呼び出す
    // ⚠️ password, systemid, clientid は固定値として設定しています
    const authResponse = await axios.post('http://auth-intra.trechina.cn/Apps/authentication/authenticate', {
      account: barcode, // ここにスキャンしたバーコードが入る
      password: "670b14728ad9902aecba32e22fa4f6bd", 
      systemid: "7c095dc3-6bea-4636-bacc-ce9abb19b597",
      clientid: "10745145"
    }, {
      headers: { 'Content-Type': 'application/json' }
    });

    const authData = authResponse.data;

    // 2. 認証結果を確認
    // successedが "0" 以外、または user情報がない場合は失敗とみなす
    if (authData.successed !== "0" || !authData.user) {
      console.log('[AUTH] 外部認証失敗:', authData.message);
      return res.status(401).json({ error: '社員情報の取得に失敗しました。' });
    }

    const externalUser = authData.user;
    console.log(`[AUTH] 社員情報取得成功: ${externalUser.name} (${externalUser.account})`);

    // 3. アプリ内のデータベースでユーザーを検索・作成
    let user = await prisma.user.findUnique({
      where: { username: externalUser.account }, // accountをIDとして利用
    });

    if (!user) {
      console.log(`[AUTH] 新規ユーザーとしてDB登録: ${externalUser.name}`);
      
      // パスワードはアプリ内では使わないのでランダム生成
      const dummyPassword = Math.random().toString(36).slice(-8) + Date.now().toString();
      const hashedPassword = await bcrypt.hash(dummyPassword, SALT_ROUNDS);

      // 所属情報があれば取得（jobs配列の先頭を使用）
      const orgCode = externalUser.jobs && externalUser.jobs.length > 0 
        ? externalUser.jobs[0].orgcode 
        : '000'; // なければデフォルト

      user = await prisma.user.create({
        data: {
          username: externalUser.account,
          password: hashedPassword,
          displayName: externalUser.name, // ★外部APIの名前をそのまま使う
          storeCode: orgCode,             // ★外部APIの組織コードを使う
        },
      });
    } else {
      // 既存ユーザーの場合、外部APIの最新情報（名前や部署）で更新しておくと親切です
      // 必要なければこの else ブロックは削除しても構いません
      const orgCode = externalUser.jobs && externalUser.jobs.length > 0 
        ? externalUser.jobs[0].orgcode 
        : user.storeCode;
      
      user = await prisma.user.update({
        where: { id: user.id },
        data: {
          displayName: externalUser.name,
          storeCode: orgCode,
        }
      });
    }

    // 4. アプリ用JWTトークンを発行
    const token = jwt.sign(
      { userId: user.id, username: user.username },
      JWT_SECRET,
      { expiresIn: '1d' }
    );

    // 5. レスポンス
    res.json({
      message: 'ログイン成功',
      token,
      user: {
        id: user.id,
        username: user.username,
        displayName: user.displayName,
        storeCode: user.storeCode,
      }
    });

  } catch (error) {
    console.error('Barcode login error:', error);
    res.status(500).json({ error: '認証サーバーへの接続に失敗しました。' });
  }
});

export default authRouter;