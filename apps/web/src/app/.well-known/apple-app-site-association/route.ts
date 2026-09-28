// apple-app-site-association (C-W3h) — iOS Universal Links statement.
//
// Served as a ROUTE HANDLER (not a public/ static file) because the file is
// extensionless: Next's static file server would send Content-Type
// application/octet-stream, while Apple requires application/json. Verified
// live: `curl -sI http://localhost:3000/.well-known/apple-app-site-association`.
//
// Owner step (docs/RELEASE.md §8.2): replace REPLACE_WITH_TEAM_ID with the
// 10-character Apple Team ID — the appIDs entry must be TEAMID.bd.asunnah.sunnahLife.
import { NextResponse } from "next/server";

export const dynamic = "force-static"; // no request-time work — cacheable at the edge

const appleAppSiteAssociation = {
  applinks: {
    apps: [],
    details: [
      {
        appIDs: ["REPLACE_WITH_TEAM_ID.bd.asunnah.sunnahLife"],
        components: [
          {
            "/": "/join/*",
            comment: "Referral landing — opens the app with the pending referral (C-W3h)",
          },
        ],
      },
    ],
  },
};

export function GET() {
  return new NextResponse(JSON.stringify(appleAppSiteAssociation, null, 2), {
    status: 200,
    headers: {
      "Content-Type": "application/json",
      "Cache-Control": "public, max-age=3600",
    },
  });
}
