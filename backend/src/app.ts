import express from 'express';
import cors from 'cors';
import path from 'path';
import authRouter from './auth/auth.controller';
import postRouter from './post/post.controller';
import likeRouter from './like/like.controller';
import userRouter from './user/user.controller';
import followRouter from './follow/follow.controller';
import storeRouter from './store/store.controller';
import rankingRouter from './ranking/ranking.controller';

const app = express();

// ▼▼▼ 1. CORS設定 (セキュリティ強化版に修正) ▼▼▼
const allowedOrigins = [
  'http://localhost:3000', // ローカル開発用
  // ★あなたのFirebase URL (本番環境)
  'https://toragram-4fc78.web.app',
  'https://toragram-4fc78.firebaseapp.com' 
];

app.use(cors({
  origin: function (origin, callback) {
    // originがない場合（スマホアプリ版やPostmanなど）は許可
    if (!origin) return callback(null, true);
    
    if (allowedOrigins.indexOf(origin) === -1) {
      // リストにないサイトからのアクセスは拒否
      const msg = '許可されていないオリジンからのアクセスです';
      return callback(new Error(msg), false);
    }
    return callback(null, true);
  },
  credentials: true,
}));
// ▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲▲

// ▼▼▼ 2. サイズ制限解除 (ここが超重要！ルーターより先に書く！) ▼▼▼
app.use(express.json({ limit: '50mb' })); 
app.use(express.urlencoded({ limit: '50mb', extended: true }));
// ▲▲▲ これで確実に大きな画像を通します ▲▲▲

// 3. ルーターのマウント設定
postRouter.use('/:postId/like', likeRouter);

// 4. ルーティング (ここより前に制限解除していないと無効になる)
app.use('/auth', authRouter);
app.use('/posts', postRouter);
app.use('/users', userRouter);
app.use('/users', followRouter);
// uploadsフォルダはCloudinaryを使うようになったので、実はもう不要ですが残しておいても害はありません
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));
app.use('/stores', storeRouter);
app.use('/ranking', rankingRouter);

app.get('/', (req, res) => {
  res.send('社内SNSバックエンドが稼働中です！');
});

export default app;