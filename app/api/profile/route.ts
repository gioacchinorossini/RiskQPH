import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../lib/prisma';
import { z } from 'zod';
import { disasterEventEmitter } from '@/lib/events';

const ProfileUpdateSchema = z.object({
  id: z.string().min(1),
  firstName: z.string().min(1).optional(),
  lastName: z.string().min(1).optional(),
  role: z.string().optional().nullable(),
  middleName: z.string().nullable().optional(),
  birthdate: z.string().nullable().optional(),
  gender: z.string().nullable().optional(),
  barangay: z.string().nullable().optional(),
  address: z.string().nullable().optional(),
  latitude: z.number().nullable().optional(),
  longitude: z.number().nullable().optional(),
  barangayMemberStatus: z.string().optional(),
});

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const id = searchParams.get('id');
    if (!id) return NextResponse.json({ message: 'Missing ID' }, { status: 400 });

    const user = await prisma.user.findUnique({
      where: { id }
    });

    if (!user) return NextResponse.json({ message: 'User not found' }, { status: 404 });

    const responseUser = {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      middleName: user.middleName,
      birthdate: user.birthdate ? user.birthdate.toISOString().slice(0, 10) : null,
      gender: user.gender,
      barangay: user.barangay,
      address: user.address,
      barangayMemberStatus: user.barangayMemberStatus,
      role: user.role,
      createdAt: user.createdAt.toISOString(),
      updatedAt: user.updatedAt.toISOString(),
    };

    return NextResponse.json({ user: responseUser }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const parsed = ProfileUpdateSchema.safeParse(body);
    if (!parsed.success) {
      return NextResponse.json({ message: 'Invalid input', errors: parsed.error.issues }, { status: 400 });
    }
    const { id, firstName, lastName, role, middleName, birthdate, gender, barangay, address, latitude, longitude, barangayMemberStatus } = parsed.data;

    const user = await prisma.user.update({
      where: { id },
      data: {
        firstName,
        lastName,
        role: role || undefined,
        middleName,
        birthdate: birthdate ? new Date(birthdate) : undefined,
        gender,
        barangay,
        address,
        latitude,
        longitude,
        barangayMemberStatus,
      }
    });

    if (latitude !== undefined || longitude !== undefined) {
      disasterEventEmitter.emit('residentUpdate', {
        barangay: user.barangay,
        resident: {
          id: user.id,
          firstName: user.firstName,
          lastName: user.lastName,
          role: user.role,
          latitude: user.latitude,
          longitude: user.longitude,
          updatedAt: user.updatedAt.toISOString(),
          // We don't know the safety status here without fetching it, 
          // but SOS/Safe updates are handled in /api/safety.
          // For location-only updates, we just send what we have.
        }
      });
    }

    const responseUser = {
      id: user.id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      middleName: user.middleName,
      barangay: user.barangay,
      barangayMemberStatus: user.barangayMemberStatus,
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

export async function DELETE(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const id = searchParams.get('id');
    if (!id) return NextResponse.json({ message: 'Missing ID' }, { status: 400 });

    await prisma.user.delete({
      where: { id }
    });

    return NextResponse.json({ message: 'User deleted successfully' }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}
