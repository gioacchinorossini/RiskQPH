import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../../lib/prisma';
import { z } from 'zod';

const ReviewSchema = z.object({
  headId: z.string().min(1),
  residentId: z.string().min(1),
  decision: z.enum(['approve', 'reject']),
});

/** Pending residents waiting for barangay head confirmation */
export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const headId = searchParams.get('headId');
    if (!headId) {
      return NextResponse.json({ message: 'Missing headId' }, { status: 400 });
    }

    const head = await prisma.user.findUnique({ where: { id: headId } });
    if (!head || head.role !== 'barangay_head' || !head.barangay) {
      return NextResponse.json({ message: 'Unauthorized' }, { status: 403 });
    }

    const pending = await prisma.user.findMany({
      where: {
        role: 'resident',
        barangay: head.barangay,
        barangayMemberStatus: 'pending',
      },
      select: {
        id: true,
        email: true,
        firstName: true,
        lastName: true,
        middleName: true,
        address: true,
        barangay: true,
        createdAt: true,
      },
      orderBy: { createdAt: 'asc' },
    });

    return NextResponse.json({ pending }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const parsed = ReviewSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json({ message: 'Invalid input' }, { status: 400 });
    }
    const { headId, residentId, decision } = parsed.data;

    const head = await prisma.user.findUnique({ where: { id: headId } });
    if (!head || head.role !== 'barangay_head' || !head.barangay) {
      return NextResponse.json({ message: 'Unauthorized' }, { status: 403 });
    }

    const resident = await prisma.user.findUnique({ where: { id: residentId } });
    if (!resident || resident.role !== 'resident') {
      return NextResponse.json({ message: 'Resident not found' }, { status: 404 });
    }
    if (resident.barangay !== head.barangay) {
      return NextResponse.json({ message: 'Wrong barangay' }, { status: 403 });
    }
    if (resident.barangayMemberStatus !== 'pending') {
      return NextResponse.json({ message: 'Not pending verification' }, { status: 400 });
    }

    const nextStatus = decision === 'approve' ? 'verified' : 'rejected';
    await prisma.user.update({
      where: { id: residentId },
      data: { barangayMemberStatus: nextStatus },
    });

    return NextResponse.json({ ok: true, status: nextStatus }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}
