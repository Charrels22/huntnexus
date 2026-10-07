# HuntNexus Web

Independent TanStack Start application for Cloudflare Workers.

## Local
```bash
npm install
cp .dev.vars.example .dev.vars
npm run dev
```

## Cloudflare
- Worker: huntnexus
- Root directory: web/app
- Production branch: main
- Build: npm run build
- Deploy: npx wrangler deploy
- Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
