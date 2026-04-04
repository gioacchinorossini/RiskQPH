'use client';

import dynamic from "next/dynamic";

const Map = dynamic< { showBarangays?: boolean }>(() => import("./Map"), {
  ssr: false,
  loading: () => <div className="map-container flex items-center justify-center bg-zinc-100 dark:bg-zinc-900 border border-zinc-200 dark:border-zinc-800">
    <div className="flex flex-col items-center gap-2">
      <div className="h-8 w-8 animate-spin rounded-full border-4 border-zinc-300 dark:border-zinc-600 border-t-zinc-900 dark:border-t-zinc-100" />
      <p className="text-sm font-medium text-zinc-600 dark:text-zinc-400">Loading Hazard Map...</p>
    </div>
  </div>
});

const MapWrapper = ({ showBarangays }: { showBarangays?: boolean }) => {
  return <Map showBarangays={showBarangays} />;
};

export default MapWrapper;
