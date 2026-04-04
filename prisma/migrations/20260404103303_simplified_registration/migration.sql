/*
  Warnings:

  - You are about to drop the column `course` on the `user` table. All the data in the column will be lost.
  - You are about to drop the column `department` on the `user` table. All the data in the column will be lost.
  - You are about to drop the column `name` on the `user` table. All the data in the column will be lost.
  - You are about to drop the column `studentId` on the `user` table. All the data in the column will be lost.
  - You are about to drop the column `yearLevel` on the `user` table. All the data in the column will be lost.
  - Added the required column `firstName` to the `User` table without a default value. This is not possible if the table is not empty.
  - Added the required column `lastName` to the `User` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE `user` DROP COLUMN `course`,
    DROP COLUMN `department`,
    DROP COLUMN `name`,
    DROP COLUMN `studentId`,
    DROP COLUMN `yearLevel`,
    ADD COLUMN `address` VARCHAR(191) NULL,
    ADD COLUMN `firstName` VARCHAR(191) NOT NULL,
    ADD COLUMN `lastName` VARCHAR(191) NOT NULL,
    ADD COLUMN `latitude` DOUBLE NULL,
    ADD COLUMN `longitude` DOUBLE NULL,
    ADD COLUMN `middleName` VARCHAR(191) NULL,
    MODIFY `role` VARCHAR(191) NOT NULL DEFAULT 'resident';
