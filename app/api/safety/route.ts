import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../lib/prisma';
import { disasterEventEmitter } from '@/lib/events';

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

    // Fetch user details to broadcast
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { firstName: true, lastName: true, barangay: true, latitude: true, longitude: true }
    });

    if (user) {
      disasterEventEmitter.emit('residentUpdate', {
        barangay: user.barangay,
        resident: {
          id: userId,
          firstName: user.firstName,
          lastName: user.lastName,
          isSafe: isSafe ?? true,
          latitude: user.latitude,
          longitude: user.longitude,
          hasResponded: true,
          updatedAt: new Date().toISOString()
        }
      });
    }

    return NextResponse.json({ safety }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}
