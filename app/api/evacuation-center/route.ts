import { NextResponse } from 'next/server';
import { prisma } from '../../../lib/prisma';

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const barangay = searchParams.get('barangay');

  if (!barangay) {
    return NextResponse.json({ message: 'Barangay name is required' }, { status: 400 });
  }

  try {
    const centers = await prisma.evacuationCenter.findMany({
      where: { barangay },
      include: {
        _count: {
          select: { evacuees: true }
        }
      }
    });

    return NextResponse.json({ centers });
  } catch (error) {
    console.error('Error fetching evacuation centers:', error);
    return NextResponse.json({ message: 'Error fetching evacuation centers' }, { status: 500 });
  }
}

export async function POST(request: Request) {
  try {
    const { id, name, barangay, latitude, longitude, capacity, type } = await request.json();

    if (!name || !barangay || latitude === undefined || longitude === undefined) {
      return NextResponse.json({ message: 'Missing required fields' }, { status: 400 });
    }

    if (id) {
      const center = await prisma.evacuationCenter.update({
        where: { id },
        data: {
          name,
          latitude,
          longitude,
          capacity: capacity ? parseInt(capacity) : null,
          type: type || null,
        }
      });
      return NextResponse.json({ center });
    } else {
      const center = await prisma.evacuationCenter.create({
        data: {
          name,
          barangay,
          latitude,
          longitude,
          capacity: capacity ? parseInt(capacity) : null,
          type: type || 'Landmark',
        }
      });
      return NextResponse.json({ center });
    }
  } catch (error) {
    console.error('Error creating/updating evacuation center:', error);
    return NextResponse.json({ message: 'Error updating evacuation center' }, { status: 500 });
  }
}

export async function DELETE(request: Request) {
  const { searchParams } = new URL(request.url);
  const id = searchParams.get('id');

  if (!id) {
    return NextResponse.json({ message: 'ID is required' }, { status: 400 });
  }

  try {
    // Delete evacuees first (due to prisma relation settings maybe, but better safe)
    await prisma.evacuee.deleteMany({
      where: { evacuationCenterId: id }
    });
    
    await prisma.evacuationCenter.delete({
      where: { id }
    });

    return NextResponse.json({ message: 'Evacuation center deleted successfully' });
  } catch (error) {
    console.error('Error deleting evacuation center:', error);
    return NextResponse.json({ message: 'Error deleting evacuation center' }, { status: 500 });
  }
}
