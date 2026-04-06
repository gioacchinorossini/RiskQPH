import { EventEmitter } from 'events';

// In Next.js dev mode, the global object is preserved between hot reloads
const globalWithEvents = global as typeof globalThis & {
  disasterEventEmitter?: EventEmitter;
};

export const disasterEventEmitter = globalWithEvents.disasterEventEmitter || new EventEmitter();
export const notificationEventEmitter = globalWithEvents.notificationEventEmitter || new EventEmitter();

if (process.env.NODE_ENV !== 'production') {
  globalWithEvents.disasterEventEmitter = disasterEventEmitter;
  globalWithEvents.notificationEventEmitter = notificationEventEmitter;
}
