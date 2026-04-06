import { NextResponse } from 'next/server';
import { prisma } from '../../../../lib/prisma';
import { broadcastResidentUpdate } from '@/lib/resident-sync';

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const evacuationCenterId = searchParams.get('evacuationCenterId');

  if (!evacuationCenterId) {
    return NextResponse.json({ message: 'Evacuation center ID is required' }, { status: 400 });
  }

  try {
    const evacuees = await prisma.evacuee.findMany({
      where: { evacuationCenterId },
      orderBy: { createdAt: 'desc' }
    });

    return NextResponse.json({ evacuees });
  } catch (error) {
    console.error('Error fetching evacuees:', error);
    return NextResponse.json({ message: 'Error fetching evacuees' }, { status: 500 });
  }
}

export async function DELETE(request: Request) {
  const { searchParams } = new URL(request.url);
  const id = searchParams.get('id');

  if (!id) {
    return NextResponse.json({ message: 'ID is required' }, { status: 400 });
  }

  try {
    const row = await prisma.evacuee.findUnique({
      where: { id },
      select: { registeredUserId: true },
    });

    await prisma.evacuee.delete({
      where: { id },
    });

    if (row?.registeredUserId) {
      await broadcastResidentUpdate(row.registeredUserId);
    }

    return NextResponse.json({ message: 'Evacuee deleted successfully' });
  } catch (error) {
    console.error('Error deleting evacuee:', error);
    return NextResponse.json({ message: 'Error deleting evacuee' }, { status: 500 });
  }
}
