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
