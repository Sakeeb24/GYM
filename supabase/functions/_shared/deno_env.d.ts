// Ambient declarations for the Deno 2 runtime (Supabase Edge Runtime).
// Lets tsc type-check without the Deno CLI.
declare namespace Deno {
  namespace env {
    function get(name: string): string | undefined;
    function toObject(): Record<string, string>;
  }
  const version: string;
  function serve(
    handler: (req: Request) => Response | Promise<Response>,
    options?: { onError?: (error: unknown, ctx: { request: Request }) => Response },
  ): void;
}

declare global {
  // node:crypto + Buffer globals come from @types/node
  const Buffer: typeof import('node:buffer').Buffer;
}
