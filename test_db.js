const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();

async function main() {
  try {
    const memberCount = await prisma.familyMember.count();
    console.log(`Success: Found ${memberCount} family members in the database.`);
  } catch (e) {
    console.error(`Error: Could not query familyMember table. Full error:`, e);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

main();
