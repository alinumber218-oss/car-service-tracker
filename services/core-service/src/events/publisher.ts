import amqplib, { Channel, ChannelModel } from 'amqplib';
import type { ServiceLogCreatedEvent } from '@car-tracker/shared-types';

let connection: ChannelModel | null = null;
let channel: Channel | null = null;

const EXCHANGE = process.env.SERVICE_LOG_EVENTS_EXCHANGE || 'service-log-events';

/**
 * Lazily connects to RabbitMQ. Connection failures are logged but never
 * crash the request path - publishing an event is a best-effort side
 * effect, not something that should block the user from saving a service log.
 */
async function getChannel(): Promise<Channel | null> {
  if (channel) return channel;

  try {
    connection = await amqplib.connect(process.env.RABBITMQ_URL || 'amqp://guest:guest@localhost:5672');
    channel = await connection.createChannel();
    await channel.assertExchange(EXCHANGE, 'fanout', { durable: true });
    return channel;
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('Could not connect to RabbitMQ, event publishing disabled:', err);
    return null;
  }
}

export async function publishServiceLogCreated(event: ServiceLogCreatedEvent): Promise<void> {
  const ch = await getChannel();
  if (!ch) return;

  ch.publish(EXCHANGE, '', Buffer.from(JSON.stringify(event)), {
    contentType: 'application/json',
    persistent: true,
  });
}
