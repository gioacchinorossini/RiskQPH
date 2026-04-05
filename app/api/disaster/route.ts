import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../lib/prisma';
import { disasterEventEmitter } from '@/lib/events';

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const barangay = searchParams.get('barangay');
    const userId = searchParams.get('userId');

    if (!barangay) {
      return NextResponse.json({ message: 'Missing barangay' }, { status: 400 });
    }

    const disaster = await prisma.disaster.findFirst({
      where: { barangay, isActive: true },
      orderBy: { createdAt: 'desc' },
      include: userId ? {
        safetyReports: {
          where: { userId },
          select: { isSafe: true }
        }
      } : undefined
    });

    if (disaster && userId) {
      const report = (disaster as any).safetyReports?.[0];
      return NextResponse.json({ 
        disaster: { ...disaster, isSafe: report?.isSafe || false } 
      }, { status: 200 });
    }

    return NextResponse.json({ disaster }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { headId, barangay, type, isActive, description } = body;

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
      
      disasterEventEmitter.emit('disasterChange', { barangay, isActive: false });
      
      return NextResponse.json({ message: 'Disaster mode deactivated' }, { status: 200 });
    }

    const disaster = await prisma.disaster.create({
      data: {
        barangay,
        type: type || 'General Emergency',
        description: description || null,
        isActive: true,
      },
    });

    disasterEventEmitter.emit('disasterChange', { barangay, isActive: true, disaster });

    return NextResponse.json({ disaster }, { status: 201 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}
