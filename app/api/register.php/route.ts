import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../lib/prisma';
import bcrypt from 'bcryptjs';
import { z } from 'zod';

const RegisterSchema = z.object({
  name: z.string().min(2),
  email: z.string().email(),
  password: z.string().min(8),
  studentId: z.string().regex(/^\d{2}-\d{4}-\d{3}$/),
  yearLevel: z.string().min(1),
  department: z.string().min(1),
  course: z.string().min(1),
  gender: z.enum(['male', 'female']),
  birthdate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/)
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const parsed = RegisterSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json({ message: 'Invalid input' }, { status: 400 });
    }
    const {
      name,
      email,
      password,
      studentId,
      yearLevel,
      department,
      course,
      gender,
      birthdate
    } = parsed.data;

    const existing = await prisma.user.findFirst({
      where: { OR: [{ email }, { studentId }] }
    });
    if (existing) {
      return NextResponse.json({ message: 'Email or Student ID already in use' }, { status: 409 });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: {
        name,
        email,
        passwordHash,
        studentId,
        yearLevel,
        department,
        course,
        gender,
        birthdate: new Date(birthdate),
        role: 'student'
      }
    });

    const responseUser = {
      id: user.id,
      name: user.name,
      email: user.email,
      studentId: user.studentId,
      yearLevel: user.yearLevel,
      department: user.department,
      course: user.course,
      gender: user.gender,
      birthdate: user.birthdate ? user.birthdate.toISOString().slice(0, 10) : null,
      role: user.role,
      createdAt: user.createdAt.toISOString(),
      updatedAt: user.updatedAt.toISOString()
    };

    return NextResponse.json({ user: responseUser }, { status: 201 });
  } catch (e) {
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}

