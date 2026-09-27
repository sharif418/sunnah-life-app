"use client";

// কোর্স — content/courses.json প্যাক থেকে কোর্স কার্ড, এনরোল (api.enroll —
// সাইন-ইন লাগে; অতিথিদের প্রম্পট), পাঠ অগ্রগতি (api.saveProgress + localStorage)।
// নোট: courses.json এখনো খালি — খালি-অবস্থার জন্য বাংলা শূন্য-স্টেট আছে।

import * as React from "react";
import { toast } from "sonner";
import { BookOpenCheck, Check, ChevronRight, Clock, GraduationCap, Layers, Radio } from "lucide-react";
import { api } from "@/lib/api";
import { getPack } from "@/lib/content";
import type { CoursesPack } from "@/lib/content";
import type { Course } from "@/types/domain";
import { useApp } from "@/lib/store";
import { toBn } from "@/lib/calendars";
import { EmptyState, SkeletonRows, StatusPill, useAsync } from "./parts";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Progress } from "@/components/ui/progress";
import { cn } from "@/lib/utils";

const progressKey = (courseId: string) => `sunnahlife-course-${courseId}`;

function readProgress(courseId: string): string[] {
  try {
    const raw = localStorage.getItem(progressKey(courseId));
    if (!raw) return [];
    const parsed = JSON.parse(raw) as { done?: string[] };
    return Array.isArray(parsed.done) ? parsed.done : [];
  } catch {
    return [];
  }
}

export function CoursesSection({
  courseId,
  lessonId,
}: {
  courseId?: string;
  lessonId?: string;
}) {
  const { nav } = useApp();
  const { data, loading, error } = useAsync<CoursesPack>(() => getPack("courses") as Promise<CoursesPack>);

  if (loading) return <SkeletonRows count={3} className="h-28" />;
  if (error) return <EmptyState icon={GraduationCap} title="কোর্স লোড করা যায়নি" hint={error} />;
  const courses: Course[] = data?.courses ?? [];
  if (courses.length === 0)
    return (
      <EmptyState
        icon={GraduationCap}
        title="কোর্স শীঘ্রই আসছে, ইনশাআল্লাহ"
        hint="আস-সুন্নাহ ফাউন্ডেশনের স্টাডি-সার্কেল ও কোর্সগুলো এখানে যুক্ত হবে। ততদিন লাইভ প্রোগ্রামগুলোতে অংশ নিন।"
        action={
          <Button variant="outline" size="sm" className="h-11 rounded-xl" onClick={() => nav("ilm", "live")}>
            <Radio className="size-4" /> লাইভ প্রোগ্রাম দেখুন
          </Button>
        }
      />
    );

  const active = courses.find((c) => c.id === courseId) ?? null;
  if (active) return <CourseDetail course={active} initialLessonId={lessonId} onBack={() => nav("ilm", "courses")} />;

  return (
    <div className="space-y-3">
      {courses.map((c) => {
        const totalMin = c.lessons.reduce((s, l) => s + l.minutes, 0);
        const done = readProgress(c.id).length;
        return (
          <Card key={c.id} className="rounded-xl p-4 shadow-card">
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0">
                <h3 className="text-[15px] font-bold leading-snug">{c.titleBn}</h3>
                <p className="mt-1 line-clamp-2 text-sm leading-relaxed text-muted-foreground">{c.descBn}</p>
              </div>
              <StatusPill tone="primary">{c.level}</StatusPill>
            </div>
            <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
              <span className="inline-flex items-center gap-1">
                <Layers className="size-3.5" /> {toBn(c.lessons.length)} পাঠ
              </span>
              <span className="inline-flex items-center gap-1">
                <Clock className="size-3.5" /> {toBn(totalMin)} মিনিট
              </span>
            </div>
            {done > 0 ? <Progress value={(100 * done) / c.lessons.length} className="mt-3 h-1.5" /> : null}
            <Button className="mt-4 h-11 w-full rounded-xl" onClick={() => nav("ilm", "course", { courseId: c.id })}>
              <BookOpenCheck className="size-4" />
              {done > 0 ? "চালিয়ে যান" : "কোর্সটি শুরু করুন"}
            </Button>
          </Card>
        );
      })}
    </div>
  );
}

function CourseDetail({ course, initialLessonId, onBack }: { course: Course; initialLessonId?: string; onBack: () => void }) {
  const { user, setAuthModal } = useApp();
  const [done, setDone] = React.useState<string[]>([]);
  const [openLesson, setOpenLesson] = React.useState<string | null>(initialLessonId ?? null);
  const [enrolled, setEnrolled] = React.useState(false);
  const [enrolling, setEnrolling] = React.useState(false);

  React.useEffect(() => {
    setDone(readProgress(course.id));
  }, [course.id]);

  const persist = async (nextDone: string[]) => {
    setDone(nextDone);
    try {
      localStorage.setItem(progressKey(course.id), JSON.stringify({ done: nextDone }));
    } catch {
      // storage blocked — progress stays in memory
    }
    if (user) {
      api.saveProgress(course.id, JSON.stringify({ done: nextDone })).catch(() => {
        /* অফলাইন হলে localStorage ভার্সনই থাকবে */
      });
    }
  };

  const enroll = async () => {
    if (!user) {
      toast.info("কোর্সে ভর্তি হতে অনুগ্রহ করে সাইন ইন করুন");
      setAuthModal(true);
      return;
    }
    setEnrolling(true);
    try {
      await api.enroll(course.id);
      setEnrolled(true);
      toast.success("ভর্তি হয়ে গেছেন — পাঠ শুরু করুন");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "ভর্তি করা যায়নি");
    } finally {
      setEnrolling(false);
    }
  };

  const toggleLesson = (lessonId: string) => {
    const next = done.includes(lessonId) ? done.filter((d) => d !== lessonId) : [...done, lessonId];
    void persist(next);
  };

  const lesson = openLesson ? course.lessons.find((l) => l.id === openLesson) ?? null : null;

  return (
    <div>
      <Button variant="ghost" className="mb-3 h-11 rounded-xl px-2 text-muted-foreground" onClick={onBack}>
        কোর্স তালিকায় ফিরুন
      </Button>
      <Card className="rounded-xl p-4 shadow-card">
        <h2 className="text-lg font-bold leading-snug">{course.titleBn}</h2>
        <p className="mt-1 text-sm leading-relaxed text-muted-foreground">{course.descBn}</p>
        <Progress value={(100 * done.length) / course.lessons.length} className="mt-3 h-1.5" />
        <p className="mt-1.5 text-xs text-muted-foreground">
          {toBn(done.length)}/{toBn(course.lessons.length)} পাঠ সম্পন্ন
        </p>
        <Button className="mt-4 h-11 w-full rounded-xl" variant={enrolled ? "secondary" : "default"} onClick={enroll} disabled={enrolled || enrolling}>
          {enrolled ? "ভর্তি আছেন" : enrolling ? "ভর্তি হচ্ছে…" : "কোর্সে ভর্তি হোন"}
        </Button>
      </Card>

      <div className="mt-4 space-y-2">
        {course.lessons.map((l, i) => {
          const isDone = done.includes(l.id);
          return (
            <button
              key={l.id}
              onClick={() => setOpenLesson(l.id)}
              className={cn(
                "tap-target flex w-full items-center gap-3 rounded-xl border border-border bg-card p-3 text-start shadow-card transition-colors hover:bg-muted/60",
                isDone && "border-primary/30"
              )}
            >
              <span
                className={cn(
                  "flex size-9 shrink-0 items-center justify-center rounded-full text-sm font-bold",
                  isDone ? "bg-primary text-primary-foreground" : "bg-primary-soft text-primary"
                )}
              >
                {isDone ? <Check className="size-4" /> : toBn(i + 1)}
              </span>
              <span className="min-w-0 flex-1">
                <span className="block truncate text-sm font-semibold">{l.titleBn}</span>
                <span className="block text-xs text-muted-foreground">{toBn(l.minutes)} মিনিট</span>
              </span>
              <ChevronRight className="size-4 shrink-0 text-muted-foreground" />
            </button>
          );
        })}
      </div>

      <Dialog open={lesson !== null} onOpenChange={(open) => !open && setOpenLesson(null)}>
        <DialogContent className="max-h-[80vh] overflow-y-auto rounded-2xl scroll-thin">
          <DialogHeader>
            <DialogTitle className="text-start">{lesson?.titleBn}</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            {lesson?.bodyBn.split(/\n{2,}/).map((para, i) => (
              <p key={i} className="text-sm leading-relaxed">
                {para}
              </p>
            ))}
          </div>
          <DialogFooter>
            <Button className="h-11 w-full rounded-xl" variant={done.includes(lesson?.id ?? "") ? "secondary" : "default"} onClick={() => lesson && toggleLesson(lesson.id)}>
              {done.includes(lesson?.id ?? "") ? "সম্পন্ন থেকে সরান" : "পাঠ সম্পন্ন হয়েছে"}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
