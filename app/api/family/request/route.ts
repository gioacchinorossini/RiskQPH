import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../../lib/prisma';
import { z } from 'zod';

const RequestSchema = z.object({
  headId: z.string(),
  applicantId: z.string()
});

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const userId = searchParams.get('userId');
    const type = searchParams.get('type') || 'received'; // received or sent

    if (!userId) {
      return NextResponse.json({ message: 'User ID required' }, { status: 400 });
    }

    const requests = await prisma.familyRequest.findMany({
      where: type === 'received' ? { headId: userId, status: 'pending' } : { applicantId: userId },
      include: {
        applicant: {
          select: { id: true, firstName: true, lastName: true, barangay: true }
        },
        head: {
          select: { id: true, firstName: true, lastName: true, barangay: true }
        }
      }
    });

    return NextResponse.json({ requests }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { headId, applicantId } = RequestSchema.parse(body);

    const existing = await prisma.familyRequest.findUnique({
      where: { headId_applicantId: { headId, applicantId } }
    });

    if (existing) {
      return NextResponse.json({ message: 'Request already exists' }, { status: 400 });
    }

    const request = await prisma.familyRequest.create({
      data: { headId, applicantId }
    });

    return NextResponse.json({ request }, { status: 201 });
  } catch (e) {
    return NextResponse.json({ message: 'Error creating request' }, { status: 500 });
  }
}

export async function PATCH(req: NextRequest) {
  try {
    const body = await req.json();
    const { id, status } = body; // status: accepted, rejected

    const request = await prisma.familyRequest.findUnique({ where: { id } });
    if (!request) return NextResponse.json({ message: 'Not found' }, { status: 404 });

    if (status === 'accepted') {
      const applicant = await prisma.user.findUnique({ where: { id: request.applicantId } });
      if (!applicant) return NextResponse.json({ message: 'Applicant not found' }, { status: 404 });

      // Create FamilyMember entry
      await prisma.familyMember.create({
        data: {
          headId: request.headId,
          userId: request.applicantId,
          firstName: applicant.firstName,
          lastName: applicant.lastName,
          relationship: 'Linked User'
        }
      });
    }

    const updated = await prisma.familyRequest.update({
      where: { id },
      data: { status }
    });

    return NextResponse.json({ updated }, { status: 200 });
  } catch (e) {
    return NextResponse.json({ message: 'Error updating' }, { status: 500 });
  }
}
