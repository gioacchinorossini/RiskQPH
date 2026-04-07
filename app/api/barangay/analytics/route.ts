import { NextRequest, NextResponse } from "next/server";
import { PrismaClient } from "@prisma/client";

const prisma = new PrismaClient();

export async function GET(req: NextRequest) {
  try {
    const { searchParams } = new URL(req.url);
    const barangay = searchParams.get("barangay");

    if (!barangay) {
      return NextResponse.json({ error: "Barangay is required" }, { status: 400 });
    }

    // 1. Resident Stats
    const totalResidents = await prisma.user.count({
      where: { barangay, role: "resident" }
    });

    const verifiedResidents = await prisma.user.count({
      where: { barangay, role: "resident", barangayMemberStatus: "verified" }
    });

    const pendingResidents = await prisma.user.count({
      where: { barangay, role: "resident", barangayMemberStatus: "pending" }
    });

    const genderStats = await prisma.user.groupBy({
      by: ['gender'],
      where: { barangay, role: "resident" },
      _count: true
    });

    // 2. Incident Report Stats
    const reportStats = await prisma.report.groupBy({
      by: ['type'],
      _count: true,
      orderBy: { _count: { type: 'desc' } }
    });

    const recentReports = await prisma.report.findMany({
      take: 10,
      orderBy: { createdAt: 'desc' },
      include: {
        user: {
          select: { firstName: true, lastName: true }
        }
      }
    });

    // 3. Disaster Stats
    const disasterStats = await prisma.disaster.groupBy({
      by: ['type'],
      where: { barangay },
      _count: true
    });

    const lastDisaster = await prisma.disaster.findFirst({
      where: { barangay },
      orderBy: { createdAt: 'desc' },
      include: {
        safetyReports: true
      }
    });

    let safetyRate = 0;
    if (lastDisaster && lastDisaster.safetyReports.length > 0) {
      const safeCount = lastDisaster.safetyReports.filter(r => r.isSafe).length;
      safetyRate = (safeCount / lastDisaster.safetyReports.length) * 100;
    }

    // 4. Evacuation Stats
    const evacuationCenters = await prisma.evacuationCenter.findMany({
      where: { barangay },
      include: {
        _count: {
          select: { evacuees: true }
        }
      }
    });

    return NextResponse.json({
      residents: {
        total: totalResidents,
        verified: verifiedResidents,
        pending: pendingResidents,
        gender: genderStats
      },
      reports: {
        byType: reportStats,
        recent: recentReports
      },
      disasters: {
        byType: disasterStats,
        lastDisaster: lastDisaster ? {
            type: lastDisaster.type,
            isActive: lastDisaster.isActive,
            safetyRate: safetyRate.toFixed(1),
            totalReports: lastDisaster.safetyReports.length
        } : null
      },
      evacuation: evacuationCenters.map(ec => ({
        name: ec.name,
        capacity: ec.capacity,
        current: ec._count.evacuees,
        occupancy: ec.capacity ? ((ec._count.evacuees / ec.capacity) * 100).toFixed(1) : 0
      }))
    });
  } catch (error) {
    console.error("Error fetching analytics:", error);
    return NextResponse.json({ error: "Failed to fetch analytics" }, { status: 500 });
  }
}
