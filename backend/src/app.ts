import express from 'express';
import authRouter from './auth/auth.controller';
import postRouter from './post/post.controller';
import commentRouter from './comment/comment.controller'; 
import likeRouter from './like/like.controller';
import userRouter from './user/user.controller';
import followRouter from './follow/follow.controller';

const app = express();
app.use(express.json({ limit: '50mb' })); 
app.use(express.urlencoded({ limit: '50mb', extended: true }));

// --- ルーターの設定 ---
app.use('/auth', authRouter);
app.use('/posts', postRouter);
app.use('/users', userRouter);
app.use('/users', followRouter);

// 💡 2. コメントルーターを /posts/:postId/comments パスにマウント
//    postRouter の *後* に定義する必要があります
postRouter.use('/:postId/comments', commentRouter);

app.get('/', (req, res) => {
  res.send('社内SNSバックエンドが稼働中です！');
});

// コメント: /posts/:postId/comments
postRouter.use('/:postId/comments', commentRouter);

// いいね: /posts/:postId/like
postRouter.use('/:postId/like', likeRouter); // 💡 2. 'like'ルーターをマウント

app.get('/', (req, res) => {
  res.send('社内SNSバックエンドが稼働中です！');
});

export default app;
