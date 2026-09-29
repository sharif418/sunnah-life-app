import { cn } from "@/lib/utils";

export function LogoMark({ className, size = 36 }: { className?: string; size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 48 48"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={cn("shrink-0", className)}
      aria-hidden="true"
    >
      <rect width="48" height="48" rx="13" fill="#1F4D3D" />
      <rect x="14.5" y="14.5" width="19" height="19" rx="2.5" stroke="#C99A3B" strokeWidth="1.6" />
      <rect
        x="14.5"
        y="14.5"
        width="19"
        height="19"
        rx="2.5"
        stroke="#C99A3B"
        strokeWidth="1.6"
        transform="rotate(45 24 24)"
      />
      <path
        d="M24 12.2c.5 0 .9.4.9.9v.5c2.8.5 4.9 2.9 4.9 5.8 0 1.5-.4 2.6-1 3.7l.9 1.6h-9.6l.9-1.6c-.6-1.1-1-2.2-1-3.7 0-2.9 2.1-5.3 4.9-5.8v-.5c0-.5.4-.9.9-.9Z"
        fill="#C99A3B"
      />
      <rect x="18.6" y="26.2" width="10.8" height="1.7" rx="0.85" fill="#C99A3B" />
      <rect x="20.2" y="29.4" width="7.6" height="1.7" rx="0.85" fill="#C99A3B" opacity="0.7" />
      <rect x="21.8" y="32.6" width="4.4" height="1.7" rx="0.85" fill="#C99A3B" opacity="0.45" />
    </svg>
  );
}

export function AppTitle({ className }: { className?: string }) {
  return (
    <div className={cn("flex flex-col leading-none", className)}>
      <span className="text-lg font-bold tracking-tight">সুন্নাহ লাইফ</span>
      {/* opacity (not a fixed muted color) so the subtitle stays readable on
          the green top bar too — the header passes text-primary-foreground. */}
      <span className="text-[10px] font-medium opacity-70">আস-সুন্নাহ ফাউন্ডেশন</span>
    </div>
  );
}
