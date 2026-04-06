import { NextResponse } from 'next/server';
import { prisma } from '../../../../lib/prisma';

export async function GET() {
  try {
    const rows = await prisma.barangayProfile.findMany({
      select: { name: true },
      orderBy: { name: 'asc' },
    });
    const barangays = rows.map((r) => r.name);
    return NextResponse.json({ barangays }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}
