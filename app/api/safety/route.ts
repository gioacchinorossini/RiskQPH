import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../lib/prisma';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { userId, disasterId, isSafe } = body;

    if (!userId || !disasterId) {
      return NextResponse.json({ message: 'Missing userId or disasterId' }, { status: 400 });
    }

    const safety = await prisma.userSafety.upsert({
      where: {
        userId_disasterId: {
          userId,
          disasterId,
        },
      },
      update: {
        isSafe: isSafe ?? true,
      },
      create: {
        userId,
        disasterId,
        isSafe: isSafe ?? true,
      },
    });

    return NextResponse.json({ safety }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}
