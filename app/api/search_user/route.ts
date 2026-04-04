import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../lib/prisma';

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const email = searchParams.get('email');
    const id = searchParams.get('id');

    if (!email && !id) {
      return NextResponse.json({ message: 'Missing email or id' }, { status: 400 });
    }

    const user = await prisma.user.findFirst({
      where: {
        OR: [
          { email: email || undefined },
          { id: id || undefined },
        ],
      },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        barangay: true,
      },
    });

    if (!user) {
      return NextResponse.json({ message: 'User not found' }, { status: 404 });
    }

    return NextResponse.json({ user }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}
