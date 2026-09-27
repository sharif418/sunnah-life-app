"use client";

export function HomeView() {
  return <SectionPlaceholder title="নামাজের সময়সূচি ও হোম" hint="এই অংশটি তৈরি হচ্ছে…" />;
}

function SectionPlaceholder({ title, hint }: { title: string; hint: string }) {
  return (
    <div className="py-16 text-center">
      <p className="text-lg font-semibold">{title}</p>
      <p className="text-sm text-muted-foreground mt-1">{hint}</p>
    </div>
  );
}
