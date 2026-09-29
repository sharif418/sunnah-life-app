import { redirect } from "next/navigation";

/** Bare /join carries no code — the landing needs one, so go home
 *  (it must never 404; shared links sometimes get truncated). */
export default function JoinIndexPage() {
  redirect("/");
}
