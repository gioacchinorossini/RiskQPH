import { NextRequest, NextResponse } from "next/server";
import { PrismaClient } from "@prisma/client";
import { writeFile, mkdir } from "fs/promises";
import path from "path";

const prisma = new PrismaClient();

export async function POST(req: NextRequest) {
  try {
    const formData = await req.formData();
    const type = formData.get("type") as string;
    const description = formData.get("description") as string;
    const latitude = parseFloat(formData.get("latitude") as string);
    const longitude = parseFloat(formData.get("longitude") as string);
    const userId = formData.get("userId") as string | null;
    const file = formData.get("file") as File | null;

    let imageUrl = null;

    if (file) {
      const bytes = await file.arrayBuffer();
      const buffer = Buffer.from(bytes);

      const uploadsDir = path.join(process.cwd(), "public", "uploads");
      
      // Ensure directory exists
      try {
        await mkdir(uploadsDir, { recursive: true });
      } catch (e) {}

      const filename = `${Date.now()}-${file.name.replace(/\s+/g, "_")}`;
      const filePath = path.join(uploadsDir, filename);

      await writeFile(filePath, buffer);
      imageUrl = `/uploads/${filename}`;
    }

    const report = await prisma.report.create({
      data: {
        type,
        description,
        latitude,
        longitude,
        imageUrl,
        userId: userId || null,
      },
    });

    return NextResponse.json(report, { status: 201 });
  } catch (error) {
    console.error("Error creating report:", error);
    return NextResponse.json({ error: "Failed to create report" }, { status: 500 });
  }
}

export async function GET() {
  try {
    const reports = await prisma.report.findMany({
      include: {
        user: {
          select: { 
            firstName: true,
            lastName: true 
          }
        }
      },
      orderBy: { createdAt: "desc" },
    });
    
    const formatted = reports.map(r => ({
      ...r,
      reporterName: r.user ? `${r.user.firstName} ${r.user.lastName}` : "Anonymous",
    }));

    return NextResponse.json(formatted);
  } catch (error) {
    console.error("Error fetching reports:", error);
    return NextResponse.json({ error: "Failed to fetch reports" }, { status: 500 });
  }
}
