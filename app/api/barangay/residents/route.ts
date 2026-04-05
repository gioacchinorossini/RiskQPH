import { NextRequest, NextResponse } from 'next/server';
import { prisma } from '../../../../lib/prisma';

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const barangay = searchParams.get('barangay');
    const disasterId = searchParams.get('disasterId');

    if (!barangay) {
      return NextResponse.json({ message: 'Missing barangay' }, { status: 400 });
    }

    // Get all residents in this barangay
    const residents = await prisma.user.findMany({
      where: { barangay, role: { in: ['resident', 'responder'] } },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        middleName: true,
        role: true,
        latitude: true,
        longitude: true,
        updatedAt: true,
        safetyStatus: disasterId ? {
          where: { disasterId },
          select: { isSafe: true, updatedAt: true }
        } : false,
      }
    });

    // Format for easier consumption
    const formatted = residents.map(r => {
      const resp = r.safetyStatus && r.safetyStatus.length > 0 ? r.safetyStatus[0] : null;
      return {
        ...r,
        hasResponded: resp !== null,
        isSafe: resp ? resp.isSafe : false,
        safetyUpdatedAt: resp ? resp.updatedAt : null,
      };
    });

    return NextResponse.json({ residents: formatted }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}
