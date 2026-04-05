import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../lib/prisma';
import { z } from 'zod';

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const barangay = searchParams.get('barangay');

    if (!barangay) {
      return NextResponse.json({ message: 'Missing barangay' }, { status: 400 });
    }

    const disaster = await prisma.disaster.findFirst({
      where: { barangay, isActive: true },
      orderBy: { createdAt: 'desc' },
    });

    return NextResponse.json({ disaster }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { headId, barangay, type, isActive } = body;

    // Verify head
    const head = await prisma.user.findUnique({ where: { id: headId } });
    if (!head || head.role !== 'barangay_head') {
      return NextResponse.json({ message: 'Unauthorized' }, { status: 403 });
    }

    if (isActive === false) {
      // Deactivate all disasters for this barangay
      await prisma.disaster.updateMany({
        where: { barangay, isActive: true },
        data: { isActive: false },
      });
      return NextResponse.json({ message: 'Disaster mode deactivated' }, { status: 200 });
    }

    const disaster = await prisma.disaster.create({
      data: {
        barangay,
        type: type || 'General Emergency',
        isActive: true,
      },
    });

    return NextResponse.json({ disaster }, { status: 201 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}
