// Location database: all 64 Bangladesh districts + major international cities.

export interface CityEntry {
  nameBn: string;
  nameEn: string;
  lat: number;
  lng: number;
  tz: number; // UTC offset hours
  country: "BD" | "INTL";
}

export const CITIES: CityEntry[] = [
  // Dhaka division
  { nameBn: "ঢাকা", nameEn: "Dhaka", lat: 23.8103, lng: 90.4125, tz: 6, country: "BD" },
  { nameBn: "গাজীপুর", nameEn: "Gazipur", lat: 23.9999, lng: 90.4203, tz: 6, country: "BD" },
  { nameBn: "নারায়ণগঞ্জ", nameEn: "Narayanganj", lat: 23.6238, lng: 90.4999, tz: 6, country: "BD" },
  { nameBn: "নরসিংদী", nameEn: "Narsingdi", lat: 23.9322, lng: 90.7151, tz: 6, country: "BD" },
  { nameBn: "মানিকগঞ্জ", nameEn: "Manikganj", lat: 23.8644, lng: 90.0047, tz: 6, country: "BD" },
  { nameBn: "মুন্সিগঞ্জ", nameEn: "Munshiganj", lat: 23.5422, lng: 90.5305, tz: 6, country: "BD" },
  { nameBn: "টাঙ্গাইল", nameEn: "Tangail", lat: 24.2513, lng: 89.9167, tz: 6, country: "BD" },
  { nameBn: "কিশোরগঞ্জ", nameEn: "Kishoreganj", lat: 24.4449, lng: 90.7766, tz: 6, country: "BD" },
  { nameBn: "ফরিদপুর", nameEn: "Faridpur", lat: 23.607, lng: 89.8429, tz: 6, country: "BD" },
  { nameBn: "মাদারীপুর", nameEn: "Madaripur", lat: 23.1641, lng: 90.1897, tz: 6, country: "BD" },
  { nameBn: "শরীয়তপুর", nameEn: "Shariatpur", lat: 23.2423, lng: 90.4348, tz: 6, country: "BD" },
  { nameBn: "রাজবাড়ী", nameEn: "Rajbari", lat: 23.7574, lng: 89.6444, tz: 6, country: "BD" },
  { nameBn: "গোপালগঞ্জ", nameEn: "Gopalganj", lat: 23.005, lng: 89.8266, tz: 6, country: "BD" },
  // Chattogram division
  { nameBn: "চট্টগ্রাম", nameEn: "Chattogram", lat: 22.3569, lng: 91.7832, tz: 6, country: "BD" },
  { nameBn: "কক্সবাজার", nameEn: "Cox's Bazar", lat: 21.4272, lng: 92.0058, tz: 6, country: "BD" },
  { nameBn: "কুমিল্লা", nameEn: "Cumilla", lat: 23.4607, lng: 91.1809, tz: 6, country: "BD" },
  { nameBn: "ব্রাহ্মণবাড়িয়া", nameEn: "Brahmanbaria", lat: 23.9571, lng: 91.1119, tz: 6, country: "BD" },
  { nameBn: "নোয়াখালী", nameEn: "Noakhali", lat: 22.8696, lng: 91.0995, tz: 6, country: "BD" },
  { nameBn: "ফেনী", nameEn: "Feni", lat: 23.0159, lng: 91.3976, tz: 6, country: "BD" },
  { nameBn: "চাঁদপুর", nameEn: "Chandpur", lat: 23.2333, lng: 90.6712, tz: 6, country: "BD" },
  { nameBn: "লক্ষ্মীপুর", nameEn: "Lakshmipur", lat: 22.9447, lng: 90.8282, tz: 6, country: "BD" },
  { nameBn: "রাঙামাটি", nameEn: "Rangamati", lat: 22.6533, lng: 92.1735, tz: 6, country: "BD" },
  { nameBn: "খাগড়াছড়ি", nameEn: "Khagrachhari", lat: 23.1193, lng: 91.9847, tz: 6, country: "BD" },
  { nameBn: "বান্দরবান", nameEn: "Bandarban", lat: 22.1953, lng: 92.2184, tz: 6, country: "BD" },
  // Sylhet division
  { nameBn: "সিলেট", nameEn: "Sylhet", lat: 24.8949, lng: 91.8687, tz: 6, country: "BD" },
  { nameBn: "মৌলভীবাজার", nameEn: "Moulvibazar", lat: 24.4829, lng: 91.7774, tz: 6, country: "BD" },
  { nameBn: "হবিগঞ্জ", nameEn: "Habiganj", lat: 24.3745, lng: 91.4155, tz: 6, country: "BD" },
  { nameBn: "সুনামগঞ্জ", nameEn: "Sunamganj", lat: 25.0658, lng: 91.395, tz: 6, country: "BD" },
  // Rajshahi division
  { nameBn: "রাজশাহী", nameEn: "Rajshahi", lat: 24.3745, lng: 88.6042, tz: 6, country: "BD" },
  { nameBn: "বগুড়া", nameEn: "Bogura", lat: 24.8465, lng: 89.3773, tz: 6, country: "BD" },
  { nameBn: "পাবনা", nameEn: "Pabna", lat: 24.0064, lng: 89.2372, tz: 6, country: "BD" },
  { nameBn: "সিরাজগঞ্জ", nameEn: "Sirajganj", lat: 24.4534, lng: 89.7007, tz: 6, country: "BD" },
  { nameBn: "নাটোর", nameEn: "Natore", lat: 24.4206, lng: 89.0004, tz: 6, country: "BD" },
  { nameBn: "নওগাঁ", nameEn: "Naogaon", lat: 24.7936, lng: 88.9318, tz: 6, country: "BD" },
  { nameBn: "জয়পুরহাট", nameEn: "Joypurhat", lat: 25.0947, lng: 89.0227, tz: 6, country: "BD" },
  { nameBn: "চাঁপাইনবাবগঞ্জ", nameEn: "Chapainawabganj", lat: 24.5965, lng: 88.2775, tz: 6, country: "BD" },
  { nameBn: "রংপুর", nameEn: "Rangpur", lat: 25.7439, lng: 89.2752, tz: 6, country: "BD" },
  { nameBn: "দিনাজপুর", nameEn: "Dinajpur", lat: 25.6217, lng: 88.6354, tz: 6, country: "BD" },
  { nameBn: "কুড়িগ্রাম", nameEn: "Kurigram", lat: 25.8072, lng: 89.6285, tz: 6, country: "BD" },
  { nameBn: "গাইবান্ধা", nameEn: "Gaibandha", lat: 25.3288, lng: 89.5281, tz: 6, country: "BD" },
  { nameBn: "লালমনিরহাট", nameEn: "Lalmonirhat", lat: 25.9923, lng: 89.2847, tz: 6, country: "BD" },
  { nameBn: "নীলফামারী", nameEn: "Nilphamari", lat: 25.9317, lng: 88.856, tz: 6, country: "BD" },
  { nameBn: "ঠাকুরগাঁও", nameEn: "Thakurgaon", lat: 26.0337, lng: 88.4616, tz: 6, country: "BD" },
  { nameBn: "পঞ্চগড়", nameEn: "Panchagarh", lat: 26.3411, lng: 88.5542, tz: 6, country: "BD" },
  // Khulna division
  { nameBn: "খুলনা", nameEn: "Khulna", lat: 22.8456, lng: 89.5403, tz: 6, country: "BD" },
  { nameBn: "যশোর", nameEn: "Jashore", lat: 23.1664, lng: 89.2081, tz: 6, country: "BD" },
  { nameBn: "সাতক্ষীরা", nameEn: "Satkhira", lat: 22.7185, lng: 89.0705, tz: 6, country: "BD" },
  { nameBn: "বাগেরহাট", nameEn: "Bagerhat", lat: 22.6516, lng: 89.7859, tz: 6, country: "BD" },
  { nameBn: "ঝিনাইদহ", nameEn: "Jhenaidah", lat: 23.545, lng: 89.1726, tz: 6, country: "BD" },
  { nameBn: "কুষ্টিয়া", nameEn: "Kushtia", lat: 23.9013, lng: 89.1206, tz: 6, country: "BD" },
  { nameBn: "মাগুরা", nameEn: "Magura", lat: 23.4855, lng: 89.4198, tz: 6, country: "BD" },
  { nameBn: "নড়াইল", nameEn: "Narail", lat: 23.1725, lng: 89.5126, tz: 6, country: "BD" },
  { nameBn: "চুয়াডাঙ্গা", nameEn: "Chuadanga", lat: 23.6402, lng: 88.8418, tz: 6, country: "BD" },
  { nameBn: "মেহেরপুর", nameEn: "Meherpur", lat: 23.7622, lng: 88.7315, tz: 6, country: "BD" },
  // Barishal division
  { nameBn: "বরিশাল", nameEn: "Barishal", lat: 22.701, lng: 90.3535, tz: 6, country: "BD" },
  { nameBn: "পটুয়াখালী", nameEn: "Patuakhali", lat: 22.3596, lng: 90.3298, tz: 6, country: "BD" },
  { nameBn: "ভোলা", nameEn: "Bhola", lat: 22.6859, lng: 90.6482, tz: 6, country: "BD" },
  { nameBn: "পিরোজপুর", nameEn: "Pirojpur", lat: 22.5841, lng: 89.9721, tz: 6, country: "BD" },
  { nameBn: "বরগুনা", nameEn: "Barguna", lat: 22.0953, lng: 90.1121, tz: 6, country: "BD" },
  { nameBn: "ঝালকাঠি", nameEn: "Jhalokati", lat: 22.6406, lng: 90.1987, tz: 6, country: "BD" },
  // Mymensingh division
  { nameBn: "ময়মনসিংহ", nameEn: "Mymensingh", lat: 24.7471, lng: 90.4203, tz: 6, country: "BD" },
  { nameBn: "জামালপুর", nameEn: "Jamalpur", lat: 24.9375, lng: 89.9372, tz: 6, country: "BD" },
  { nameBn: "নেত্রকোণা", nameEn: "Netrokona", lat: 24.8103, lng: 90.7279, tz: 6, country: "BD" },
  { nameBn: "শেরপুর", nameEn: "Sherpur", lat: 25.0205, lng: 90.0153, tz: 6, country: "BD" },
  // International
  { nameBn: "মক্কা", nameEn: "Makkah", lat: 21.3891, lng: 39.8579, tz: 3, country: "INTL" },
  { nameBn: "মদিনা", nameEn: "Madinah", lat: 24.5247, lng: 39.5692, tz: 3, country: "INTL" },
  { nameBn: "রিয়াদ", nameEn: "Riyadh", lat: 24.7136, lng: 46.6753, tz: 3, country: "INTL" },
  { nameBn: "দুবাই", nameEn: "Dubai", lat: 25.2048, lng: 55.2708, tz: 4, country: "INTL" },
  { nameBn: "দোহা", nameEn: "Doha", lat: 25.2854, lng: 51.531, tz: 3, country: "INTL" },
  { nameBn: "কুয়েত সিটি", nameEn: "Kuwait City", lat: 29.3759, lng: 47.9774, tz: 3, country: "INTL" },
  { nameBn: "কায়রো", nameEn: "Cairo", lat: 30.0444, lng: 31.2357, tz: 2, country: "INTL" },
  { nameBn: "ইস্তাম্বুল", nameEn: "Istanbul", lat: 41.0082, lng: 28.9784, tz: 3, country: "INTL" },
  { nameBn: "লন্ডন", nameEn: "London", lat: 51.5074, lng: -0.1278, tz: 0, country: "INTL" },
  { nameBn: "নিউ ইয়র্ক", nameEn: "New York", lat: 40.7128, lng: -74.006, tz: -5, country: "INTL" },
  { nameBn: "টরন্টো", nameEn: "Toronto", lat: 43.6532, lng: -79.3832, tz: -5, country: "INTL" },
  { nameBn: "কুয়ালালামপুর", nameEn: "Kuala Lumpur", lat: 3.139, lng: 101.6869, tz: 8, country: "INTL" },
  { nameBn: "সিঙ্গাপুর", nameEn: "Singapore", lat: 1.3521, lng: 103.8198, tz: 8, country: "INTL" },
  { nameBn: "করাচি", nameEn: "Karachi", lat: 24.8607, lng: 67.0011, tz: 5, country: "INTL" },
  { nameBn: "দিল্লি", nameEn: "Delhi", lat: 28.7041, lng: 77.1025, tz: 5.5, country: "INTL" },
  { nameBn: "কলকাতা", nameEn: "Kolkata", lat: 22.5726, lng: 88.3639, tz: 5.5, country: "INTL" },
  { nameBn: "সিডনি", nameEn: "Sydney", lat: -33.8688, lng: 151.2093, tz: 10, country: "INTL" },
  { nameBn: "মেলবোর্ন", nameEn: "Melbourne", lat: -37.8136, lng: 144.9631, tz: 10, country: "INTL" },
  { nameBn: "টোকিও", nameEn: "Tokyo", lat: 35.6762, lng: 139.6503, tz: 9, country: "INTL" },
];

export const DHAKA: CityEntry = CITIES[0];

export function findCity(name: string): CityEntry | undefined {
  const lower = name.toLowerCase();
  return CITIES.find(
    (c) => c.nameEn.toLowerCase() === lower || c.nameBn === name
  );
}
