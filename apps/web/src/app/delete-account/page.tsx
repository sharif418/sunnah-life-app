import type { Metadata } from "next";
import { DeleteAccountFlow } from "./delete-account-flow";

// The web half of Google Play's account-deletion rule: the listing links
// here, so a member can delete their account without the app installed.

export const metadata: Metadata = {
  title: "অ্যাকাউন্ট মুছে ফেলুন",
  description: "সুন্নাহ লাইফ অ্যাকাউন্ট ও তার তথ্য মুছে ফেলার পাতা।",
};

export default function DeleteAccountPage() {
  return <DeleteAccountFlow />;
}
