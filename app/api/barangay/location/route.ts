import { NextResponse } from 'next/server';
import { prisma } from '../../../../lib/prisma';

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const name = searchParams.get('name');

  if (!name) {
    return NextResponse.json({ message: 'Barangay name is required' }, { status: 400 });
  }

  try {
    const profile = await prisma.barangayProfile.findUnique({
      where: { name },
    });

    return NextResponse.json({ profile });
  } catch (error) {
    return NextResponse.json({ message: 'Error fetching barangay profile' }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const { name, hqLatitude, hqLongitude } = await request.json();

    if (!name) {
      return NextResponse.json({ message: 'Barangay name is required' }, { status: 400 });
    }

    const profile = await prisma.barangayProfile.upsert({
      where: { name },
      update: {
        hqLatitude,
        hqLongitude,
      },
      create: {
        name,
        hqLatitude,
        hqLongitude,
      },
    });

    return NextResponse.json({ profile });
  } catch (error) {
    return NextResponse.json({ message: 'Error updating barangay profile' }, { status: 500 });
  }
}
