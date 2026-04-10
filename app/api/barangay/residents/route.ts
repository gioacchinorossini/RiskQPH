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

    // Verified members only (pending self-registrations are excluded until barangay head approves)
    const residents = await prisma.user.findMany({
      where: {
        barangay,
        role: { in: ['resident', 'responder'] },
      },
      select: {
        id: true,
        firstName: true,
        lastName: true,
        middleName: true,
        role: true,
        barangayMemberStatus: true,
        latitude: true,
        longitude: true,
        updatedAt: true,
        safetyStatus: disasterId ? {
          where: { disasterId },
          select: { isSafe: true, updatedAt: true }
        } : false,
      }
    });

    const userIds = residents.map((r) => r.id);
    const evacRows =
      userIds.length === 0
        ? []
        : await prisma.evacuee.findMany({
            where: { registeredUserId: { in: userIds } },
            orderBy: { updatedAt: 'desc' },
            include: {
              evacuationCenter: { select: { id: true, name: true } },
            },
          });

    const evacByUser = new Map<string, { id: string; name: string }>();
    for (const e of evacRows) {
      if (e.registeredUserId && !evacByUser.has(e.registeredUserId)) {
        evacByUser.set(e.registeredUserId, {
          id: e.evacuationCenter.id,
          name: e.evacuationCenter.name,
        });
      }
    }

    // Format for easier consumption (omit Prisma relation arrays from JSON)
    const formatted = residents.map((r) => {
      const { safetyStatus, ...base } = r as typeof r & {
        safetyStatus?: { isSafe: boolean; updatedAt: Date }[] | false;
      };
      const resp =
        Array.isArray(safetyStatus) && safetyStatus.length > 0
          ? safetyStatus[0]
          : null;
      const ev = evacByUser.get(r.id);
      return {
        ...base,
        hasResponded: resp !== null,
        isSafe: resp ? resp.isSafe : false,
        safetyUpdatedAt: resp ? resp.updatedAt : null,
        evacuationCenterId: ev?.id ?? null,
        evacuationCenterName: ev?.name ?? null,
      };
    });

    return NextResponse.json({ residents: formatted }, { status: 200 });
  } catch (e) {
    console.error(e);
    return NextResponse.json({ message: 'Server error' }, { status: 500 });
  }
}
