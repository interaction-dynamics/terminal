import type { NextRequest } from 'next/server';
import { getRouteHandlers } from '@ship-it/adapters/authentication';

const handlers = await getRouteHandlers();

export const GET = (req: NextRequest) => handlers.GET(req);
export const POST = (req: NextRequest) => handlers.POST(req);
