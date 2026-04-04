import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../lib/prisma';
import { z } from 'zod';

const ProfileUpdateSchema = z.object({
  id: z.string().min(1),
  firstName: z.string().min(1).optional(),
  lastName: z.string().min(1).optional(),
  middleName: z.string().nullable().optional(),
  birthdate: z.string().nullable().optional(),
  gender: z.string().nullable().optional(),
  barangay: z.string().nullable().optional(),
  address: z.string().nullable().optional(),
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const parsed = ProfileUpdateSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json({ message: 'Invalid input', errors: parsed.error.issues }, { status: 400 });
    }
    const { id, firstName, lastName, middleName, birthdate, gender, barangay, address } = parsed.data;

    const user = await prisma.user.update({
      where: { id },
      data: {
        firstName,
        lastName,
        middleName,
        birthdate: birthdate ? new Date(birthdate) : undefined,
        gender,
        barangay,
        address,
      }
    });

    const responseUser = {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      middleName: user.middleName,
      barangay: user.barangay,
      role: user.role,
      createdAt: user.createdAt.toISOString(),
      updatedAt: user.updatedAt.toISOString()
    };

    return NextResponse.json({ user: responseUser }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}
