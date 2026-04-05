import { NextResponse } from 'next/server';
import { prisma } from '../../../../lib/prisma';

export async function POST(request: Request) {
  try {
    const { 
      evacuationCenterId, 
      firstName, 
      lastName, 
      middleName, 
      gender, 
      age, 
      medicalNotes, 
      addedById 
    } = await request.json();

    if (!evacuationCenterId || !firstName || !lastName || !addedById) {
      return NextResponse.json({ message: 'Missing required fields' }, { status: 400 });
    }

    const evacuee = await prisma.evacuee.create({
      data: {
        evacuationCenterId,
        firstName,
        lastName,
        middleName,
        gender,
        age: age ? parseInt(age) : null,
        medicalNotes,
        addedById,
      }
    });

    return NextResponse.json({ evacuee });
  } catch (error) {
    console.error('Error registering evacuee:', error);
    return NextResponse.json({ message: 'Error registering evacuee' }, { status: 500 });
  }
}
