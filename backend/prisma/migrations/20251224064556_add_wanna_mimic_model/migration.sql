/*
  Warnings:

  - You are about to drop the `comments` table. If the table is not empty, all the data it contains will be lost.
  - A unique constraint covering the columns `[user_id,post_id,type]` on the table `likes` will be added. If there are existing duplicate values, this will fail.

*/
-- DropForeignKey
ALTER TABLE "comments" DROP CONSTRAINT "comments_author_id_fkey";

-- DropForeignKey
ALTER TABLE "comments" DROP CONSTRAINT "comments_post_id_fkey";

-- DropIndex
DROP INDEX "likes_user_id_post_id_key";

-- AlterTable
ALTER TABLE "likes" ADD COLUMN     "type" TEXT NOT NULL DEFAULT 'LIKE';

-- DropTable
DROP TABLE "comments";

-- CreateTable
CREATE TABLE "Store" (
    "id" TEXT NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Store_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wanna_mimics" (
    "id" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "userId" TEXT NOT NULL,
    "postId" TEXT NOT NULL,

    CONSTRAINT "wanna_mimics_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "Store_code_key" ON "Store"("code");

-- CreateIndex
CREATE UNIQUE INDEX "wanna_mimics_userId_postId_key" ON "wanna_mimics"("userId", "postId");

-- CreateIndex
CREATE UNIQUE INDEX "likes_user_id_post_id_type_key" ON "likes"("user_id", "post_id", "type");

-- AddForeignKey
ALTER TABLE "users" ADD CONSTRAINT "users_store_code_fkey" FOREIGN KEY ("store_code") REFERENCES "Store"("code") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wanna_mimics" ADD CONSTRAINT "wanna_mimics_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wanna_mimics" ADD CONSTRAINT "wanna_mimics_postId_fkey" FOREIGN KEY ("postId") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;
