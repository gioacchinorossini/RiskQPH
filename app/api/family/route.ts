import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../lib/prisma';
import { z } from 'zod';

const FamilyMemberSchema = z.object({
  headId: z.string(),
  firstName: z.string().min(1),
  lastName: z.string().min(1),
  middleName: z.string().optional().nullable(),
  relationship: z.string().min(1),
  birthdate: z.string().optional().nullable(),
  gender: z.string().optional().nullable(),
  medicalNotes: z.string().optional().nullable(),
  userId: z.string().optional().nullable(), // Optional link to registered user
});

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const headId = searchParams.get('headId');

    if (!headId) {
      return NextResponse.json({ message: 'Missing headId' }, { status: 400 });
    }

    const members = await prisma.familyMember.findMany({
      where: { headId },
      include: {
        linkedUser: {
          select: {
            latitude: true,
            longitude: true,
            role: true,
          }
        }
      },
      orderBy: { createdAt: 'desc' },
    });

    return NextResponse.json({ members }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const parsed = FamilyMemberSchema.safeParse(body);

    if (!parsed.success) {
      return NextResponse.json({ message: 'Invalid input', errors: parsed.error.issues }, { status: 400 });
    }

    const data = parsed.data;

    // Check if already linked to prevent duplicates
    if (data.userId) {
      const existing = await prisma.familyMember.findFirst({
        where: { headId: data.headId, userId: data.userId }
      });
      if (existing) {
        return NextResponse.json({ message: 'Member already linked', member: existing }, { status: 200 });
      }
    }

    const member = await prisma.familyMember.create({
      data: {
        headId: data.headId,
        firstName: data.firstName,
        lastName: data.lastName,
        middleName: data.middleName,
        relationship: data.relationship,
        birthdate: data.birthdate ? new Date(data.birthdate) : null,
        gender: data.gender,
        medicalNotes: data.medicalNotes,
        userId: data.userId,
      },
    });

    // RECIPROCAL LINKING
    if (data.userId) {
      const headUser = await prisma.user.findUnique({ where: { id: data.headId } });
      if (headUser) {
        const reciprocalExists = await prisma.familyMember.findFirst({
          where: { headId: data.userId, userId: data.headId }
        });

        if (!reciprocalExists) {
          await prisma.familyMember.create({
            data: {
              headId: data.userId,
              userId: data.headId,
              firstName: headUser.firstName,
              lastName: headUser.lastName,
              relationship: 'Family Member',
              gender: headUser.gender,
            }
          });
        }
      }
    }

    return NextResponse.json({ member }, { status: 201 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}

export async function DELETE(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const id = searchParams.get('id');

    if (!id) {
      return NextResponse.json({ message: 'Missing id' }, { status: 400 });
    }

    await prisma.familyMember.delete({
      where: { id },
    });

    return NextResponse.json({ message: 'Deleted' }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}
