// Qibla direction (great-circle bearing to the Kaaba) + distance helpers.

export const KAABA = { lat: 21.4224779, lng: 39.8251832 }; // Masjid al-Haram

const DEG = Math.PI / 180;

/** Initial bearing (degrees from true north) from a location to the Kaaba. */
export function qiblaBearing(lat: number, lng: number): number {
  const dLng = (KAABA.lng - lng) * DEG;
  const φ1 = lat * DEG;
  const φ2 = KAABA.lat * DEG;
  const y = Math.sin(dLng);
  const x = Math.cos(φ1) * Math.tan(φ2) - Math.sin(φ1) * Math.cos(dLng);
  let brng = Math.atan2(y, x) / DEG;
  brng = ((brng % 360) + 360) % 360;
  return brng;
}

/** Great-circle distance in km. */
export function distanceKm(lat1: number, lng1: number, lat2: number, lng2: number): number {
  const R = 6371;
  const dLat = (lat2 - lat1) * DEG;
  const dLng = (lng2 - lng1) * DEG;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1 * DEG) * Math.cos(lat2 * DEG) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/** Compass-point label in Bengali for a bearing. */
export function compassLabelBn(bearing: number): string {
  const points: [number, string][] = [
    [0, "উত্তর"], [45, "উত্তর-পূর্ব"], [90, "পূর্ব"], [135, "দক্ষিণ-পূর্ব"],
    [180, "দক্ষিণ"], [225, "দক্ষিণ-পশ্চিম"], [270, "পশ্চিম"], [315, "উত্তর-পশ্চিম"],
  ];
  let best = points[0];
  let bestDiff = 360;
  for (const p of points) {
    const diff = Math.min(Math.abs(bearing - p[0]), 360 - Math.abs(bearing - p[0]));
    if (diff < bestDiff) {
      bestDiff = diff;
      best = p;
    }
  }
  return best[1];
}
