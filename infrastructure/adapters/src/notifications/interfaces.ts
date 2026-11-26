export interface Notification {
  message: string;
  title?: string;
  channel?: string;
}

export type SendNotification = (notification: Notification) => Promise<void>;

export interface NotificationProvider {
  sendNotification: SendNotification;
}
