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
      const heartbeat = setInterval(() => {
        controller.enqueue(encoder.encode(': heartbeat\n\n'));
      }, 30000);

      const onResidentUpdate = (data: any) => {
        if (data.barangay === barangay) {
          controller.enqueue(encoder.encode(`data: ${JSON.stringify(data.resident)}\n\n`));
        }
      };

      disasterEventEmitter.on('residentUpdate', onResidentUpdate);

      req.signal.onabort = () => {
        clearInterval(heartbeat);
        disasterEventEmitter.off('residentUpdate', onResidentUpdate);
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
