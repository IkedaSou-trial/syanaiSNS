import { v2 as cloudinary } from 'cloudinary';
import { CloudinaryStorage } from 'multer-storage-cloudinary';
import multer from 'multer';

// Cloudinaryの設定
cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

// ストレージ設定
const storage = new CloudinaryStorage({
  cloudinary: cloudinary,
  params: async (req, file) => {
    return {
      folder: 'shainai_sns_posts', // Cloudinary上のフォルダ名
      allowed_formats: ['jpg', 'png', 'jpeg', 'heic'], // 許可する形式
      // 💡 ここで画像をリサイズ・圧縮して「軽く」します
      transformation: [{ width: 1000, crop: 'limit', quality: 'auto' }],
    };
  },
});

export const upload = multer({ storage: storage });