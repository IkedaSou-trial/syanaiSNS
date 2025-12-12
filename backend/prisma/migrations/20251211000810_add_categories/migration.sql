-- AlterTable
ALTER TABLE "posts" ADD COLUMN     "category" TEXT NOT NULL DEFAULT 'その他';

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "interestedCategories" TEXT DEFAULT '[]';
