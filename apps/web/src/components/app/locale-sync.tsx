"use client";

// <html lang dir> per locale. The root layout is a server component and
// statically Bengali (the app's default); this client effect keeps the
// document root in sync when the store's locale changes — bn/en → ltr,
// ar → rtl. Mounted once from the root layout so every route (app, join
// landing) benefits.

import * as React from "react";
import { useApp } from "@/lib/store";

export function LocaleSync() {
  const lang = useApp((s) => s.profile.language);

  React.useEffect(() => {
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";
  }, [lang]);

  return null;
}
