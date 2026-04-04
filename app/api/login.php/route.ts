import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../lib/prisma';
import bcrypt from 'bcryptjs';
import { z } from 'zod';

const LoginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1)
});

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const parsed = LoginSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json({ message: 'Invalid input' }, { status: 400 });
    }
    const { email, password } = parsed.data;

    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) {
      return NextResponse.json({ message: 'Invalid credentials' }, { status: 401 });
    }
    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) {
      return NextResponse.json({ message: 'Invalid credentials' }, { status: 401 });
    }

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

    return NextResponse.json({ user: responseUser }, { status: 200 });
  } catch (e) {
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}

