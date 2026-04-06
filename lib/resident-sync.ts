import { prisma } from '@/lib/prisma';
import { disasterEventEmitter } from '@/lib/events';

/** Same shape as entries in GET /api/barangay/residents (for SSE + clients). */
export async function buildResidentBroadcastPayload(
  userId: string,
): Promise<{ barangay: string; resident: Record<string, unknown> } | null> {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: {
      id: true,
      firstName: true,
      lastName: true,
      middleName: true,
      role: true,
      latitude: true,
      longitude: true,
      updatedAt: true,
      barangay: true,
    },
  });

  if (!user?.barangay) return null;

  const activeDisaster = await prisma.disaster.findFirst({
    where: { barangay: user.barangay, isActive: true },
    orderBy: { createdAt: 'desc' },
  });

  let safetyRow: { isSafe: boolean; updatedAt: Date } | null = null;
  if (activeDisaster) {
    safetyRow = await prisma.userSafety.findUnique({
      where: {
        userId_disasterId: { userId, disasterId: activeDisaster.id },
      },
    });
  }

  const latestEvac = await prisma.evacuee.findFirst({
    where: { registeredUserId: userId },
    orderBy: { updatedAt: 'desc' },
    include: {
      evacuationCenter: { select: { id: true, name: true } },
    },
  });

  const { barangay, ...rest } = user;

  const resident: Record<string, unknown> = {
    ...rest,
    hasResponded: safetyRow !== null,
    isSafe: safetyRow ? safetyRow.isSafe : false,
    safetyUpdatedAt: safetyRow ? safetyRow.updatedAt : null,
    evacuationCenterId: latestEvac?.evacuationCenter.id ?? null,
    evacuationCenterName: latestEvac?.evacuationCenter.name ?? null,
  };

  return { barangay, resident };
}

export async function broadcastResidentUpdate(userId: string): Promise<void> {
  const payload = await buildResidentBroadcastPayload(userId);
  if (payload) {
    disasterEventEmitter.emit('residentUpdate', payload);
  }
}
