import * as dotenv from 'dotenv';
dotenv.config();

// ここで秘密鍵を一元管理します
export const JWT_SECRET = process.env.JWT_SECRET || 'YOUR_SUPER_SECRET_KEY';