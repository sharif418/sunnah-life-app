import { cn } from "@/lib/utils";

export function Skeleton({ className }: { className?: string }) {
  return <div className={cn("skeleton h-5 w-full", className)} aria-hidden />;
}

/** A block of skeleton rows for table surfaces. */
export function TableSkeleton({ rows = 6, cols = 5 }: { rows?: number; cols?: number }) {
  return (
    <div className="space-y-2.5 p-5" role="status" aria-label="লোড হচ্ছে">
      <div className="flex gap-3">
        {Array.from({ length: cols }).map((_, i) => (
          <Skeleton key={i} className="h-4 flex-1" />
        ))}
      </div>
      {Array.from({ length: rows }).map((_, r) => (
        <div key={r} className="flex gap-3">
          {Array.from({ length: cols }).map((_, i) => (
            <Skeleton key={i} className="h-9 flex-1" />
          ))}
        </div>
      ))}
    </div>
  );
}

export function CardSkeleton({ lines = 3, className }: { lines?: number; className?: string }) {
  return (
    <div className={cn("rounded-lg border border-border bg-card p-5 shadow-card", className)} role="status" aria-label="লোড হচ্ছে">
      <Skeleton className="h-5 w-2/5" />
      <div className="mt-4 space-y-2.5">
        {Array.from({ length: lines }).map((_, i) => (
          <Skeleton key={i} className={i === lines - 1 ? "h-4 w-3/5" : "h-4"} />
        ))}
      </div>
    </div>
  );
}
