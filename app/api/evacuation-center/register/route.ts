import { NextResponse } from 'next/server';
import { prisma } from '../../../../lib/prisma';
import { broadcastResidentUpdate } from '@/lib/resident-sync';

export async function POST(request: Request) {
  try {
    const body = await request.json();
    const {
      evacuationCenterId,
      firstName,
      lastName,
      middleName,
      gender,
      age,
      medicalNotes,
      addedById,
      registeredUserId,
    } = body as Record<string, unknown>;

    if (!evacuationCenterId || !firstName || !lastName || !addedById) {
      return NextResponse.json({ message: 'Missing required fields' }, { status: 400 });
    }

    const regUserId =
      typeof registeredUserId === 'string' && registeredUserId.length > 0
        ? registeredUserId
        : null;

    if (!regUserId) {
      return NextResponse.json(
        {
          message:
            'Registration requires a scanned resident QR (registered user id). Use the QR scanner to register evacuees.',
        },
        { status: 400 },
      );
    }

    const existing = await prisma.evacuee.findFirst({
      where: {
        evacuationCenterId: evacuationCenterId as string,
        registeredUserId: regUserId,
      },
    });
    if (existing) {
      return NextResponse.json(
        { message: 'This person is already registered at this evacuation center', evacuee: existing },
        { status: 409 },
      );
    }

    const evacuee = await prisma.evacuee.create({
      data: {
        evacuationCenterId: evacuationCenterId as string,
        firstName: firstName as string,
        lastName: lastName as string,
        middleName: (middleName as string | undefined) || null,
        gender: (gender as string | undefined) || null,
        age: (() => {
          if (age == null || age === '') return null;
          const n = parseInt(String(age), 10);
          return Number.isFinite(n) ? n : null;
        })(),
        medicalNotes: (medicalNotes as string | undefined) || null,
        addedById: addedById as string,
        registeredUserId: regUserId,
      },
    });

    await broadcastResidentUpdate(regUserId);

    return NextResponse.json({ evacuee });
  } catch (error) {
    console.error('Error registering evacuee:', error);
    return NextResponse.json({ message: 'Error registering evacuee' }, { status: 500 });
  }
}
