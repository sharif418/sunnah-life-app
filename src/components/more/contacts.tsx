"use client";

// যোগাযোগ ও লিংক — /api/config → প্রতিষ্ঠানের ঠিকানা + বাহ্যিক গ্রুপ লিংক।

import * as React from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { SubShell, SectionLabel, ErrorRetry } from "@/components/more/bits";
import { api } from "@/lib/api";
import type { AppConfig } from "@/types/domain";
import { Building2, Phone, Mail, ExternalLink, Link as LinkIcon, Users } from "lucide-react";

export function ContactsView() {
  const [config, setConfig] = React.useState<AppConfig | null>(null);
  const [error, setError] = React.useState(false);
  const [reload, setReload] = React.useState(0);

  React.useEffect(() => {
    let alive = true;
    setConfig(null);
    setError(false);
    api
      .config()
      .then((c) => alive && setConfig(c))
      .catch(() => alive && setError(true));
    return () => {
      alive = false;
    };
  }, [reload]);

  return (
    <SubShell title="যোগাযোগ ও লিংক">
      {error ? (
        <ErrorRetry message="তথ্য আনা যায়নি।" onRetry={() => setReload((r) => r + 1)} />
      ) : config === null ? (
        <div className="space-y-3">
          {[0, 1, 2].map((i) => (
            <Skeleton key={i} className="h-28 rounded-xl" />
          ))}
        </div>
      ) : (
        <div className="space-y-5">
          {/* প্রতিষ্ঠানসমূহ */}
          <div className="space-y-3">
            <SectionLabel icon={<Building2 className="size-4" />}>প্রতিষ্ঠানসমূহ</SectionLabel>
            {config.contacts.map((c, i) => (
              <Card key={i} className="rounded-xl shadow-card">
                <CardContent className="p-4">
                  <p className="font-bold">{c.org}</p>
                  {c.descBn && (
                    <p className="mt-1 text-sm text-muted-foreground leading-relaxed">{c.descBn}</p>
                  )}
                  <div className="mt-3 flex flex-wrap gap-2">
                    {c.phone && (
                      <Button
                        variant="outline"
                        size="sm"
                        className="h-11 rounded-xl"
                        onClick={() => window.open(`tel:${c.phone}`, "_self")}
                      >
                        <Phone className="size-4" /> {c.phone}
                      </Button>
                    )}
                    {c.email && (
                      <Button
                        variant="outline"
                        size="sm"
                        className="h-11 rounded-xl"
                        onClick={() => window.open(`mailto:${c.email}`, "_self")}
                      >
                        <Mail className="size-4" /> {c.email}
                      </Button>
                    )}
                    {c.website && (
                      <Button
                        variant="secondary"
                        size="sm"
                        className="h-11 rounded-xl"
                        onClick={() => window.open(c.website, "_blank", "noopener,noreferrer")}
                      >
                        <ExternalLink className="size-4" /> ওয়েবসাইট
                      </Button>
                    )}
                    {c.address && <p className="w-full text-xs text-muted-foreground">{c.address}</p>}
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>

          {/* গ্রুপ ও লিংক */}
          <div className="space-y-3">
            <SectionLabel icon={<Users className="size-4" />}>গ্রুপ ও লিংক</SectionLabel>
            <Card className="rounded-xl shadow-card">
              <CardContent className="p-2">
                <ul>
                  {config.groups.map((g, i) => (
                    <li key={i}>
                      <button
                        onClick={() => window.open(g.url, "_blank", "noopener,noreferrer")}
                        className="tap-target w-full flex items-center gap-3 rounded-xl px-3 py-3 text-start hover:bg-muted transition-colors"
                        aria-label={`${g.titleBn} — নতুন ট্যাবে খুলুন`}
                      >
                        <span className="flex size-10 shrink-0 items-center justify-center rounded-full bg-primary-soft text-primary">
                          <LinkIcon className="size-4" />
                        </span>
                        <span className="flex-1 min-w-0">
                          <span className="block text-sm font-semibold leading-snug">{g.titleBn}</span>
                          {g.descBn && (
                            <span className="mt-0.5 block text-xs text-muted-foreground leading-snug">
                              {g.descBn}
                            </span>
                          )}
                        </span>
                        <ExternalLink className="size-4 text-muted-foreground shrink-0" />
                      </button>
                    </li>
                  ))}
                </ul>
              </CardContent>
            </Card>
          </div>
        </div>
      )}
    </SubShell>
  );
}
