import { NextRequest } from 'next/server';
import { disasterEventEmitter } from '@/lib/events';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const barangay = searchParams.get('barangay');

  if (!barangay) {
    return new Response('Missing barangay', { status: 400 });
  }

  const encoder = new TextEncoder();

  const stream = new ReadableStream({
    start(controller) {
      // Periodic heartbeat to keep connection alive
      const heartbeat = setInterval(() => {
        controller.enqueue(encoder.encode(': heartbeat\n\n'));
      }, 30000);

      const onDisasterChange = (data: any) => {
        if (data.barangay === barangay) {
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(data)}\n\n`));
        }
      };

      disasterEventEmitter.on('disasterChange', onDisasterChange);

      req.signal.onabort = () => {
        clearInterval(heartbeat);
        disasterEventEmitter.off('disasterChange', onDisasterChange);
      };
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  });
}
