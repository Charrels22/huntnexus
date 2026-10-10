import { useMemo } from "react";
import { MapPin } from "lucide-react";

const X_MIN = 31744;
const Y_MIN = 30976;
const FLOOR_WIDTH = 2560;
const FLOOR_HEIGHT = 2048;

export type TibiaCoordinate = { x: number; y: number; z: number };

export function parseMapperCoords(value: unknown): TibiaCoordinate | null {
  if (typeof value !== "string") return null;

  const match = value.match(
    /Mapper Coords\|(?:text=[^|}]+\|)?(\d+)\.(\d+)\|(\d+)\.(\d+)\|(\d+)/i,
  );

  if (!match) return null;

  const x = Number(match[1]) * 256 + Number(match[2]);
  const y = Number(match[3]) * 256 + Number(match[4]);
  const z = Number(match[5]);

  if (![x, y, z].every(Number.isFinite)) return null;
  return { x, y, z };
}

function floorId(z: number) {
  return String(Math.min(15, Math.max(0, z))).padStart(2, "0");
}

export function CanonicalTibiaMap({
  location,
  label = "Local da hunt",
}: {
  location: unknown;
  label?: string;
}) {
  const coords = useMemo(() => parseMapperCoords(location), [location]);

  if (!coords) {
    return (
      <div className="grid min-h-56 place-items-center rounded-2xl border border-dashed border-white/8 bg-slate-950/45 text-center">
        <div>
          <MapPin className="mx-auto size-5 text-slate-700" />
          <div className="mt-2 text-xs text-slate-600">Coordenada de mapa indisponível</div>
        </div>
      </div>
    );
  }

  const left = coords.x - X_MIN;
  const top = coords.y - Y_MIN;
  const imageUrl = `https://tibiamaps.github.io/tibia-map-data/floor-${floorId(coords.z)}-map.png`;

  const translateX = Math.min(0, Math.max(520 - FLOOR_WIDTH, 260 - left));
  const translateY = Math.min(0, Math.max(360 - FLOOR_HEIGHT, 180 - top));

  return (
    <div className="overflow-hidden rounded-2xl border border-white/8 bg-black">
      <div className="relative h-[360px] overflow-hidden">
        <img
          src={imageUrl}
          alt={`Minimap real do Tibia — ${label}`}
          loading="lazy"
          decoding="async"
          width={FLOOR_WIDTH}
          height={FLOOR_HEIGHT}
          className="absolute max-w-none [image-rendering:pixelated]"
          style={{
            width: FLOOR_WIDTH,
            height: FLOOR_HEIGHT,
            transform: `translate(${translateX}px, ${translateY}px)`,
          }}
        />
        <div className="pointer-events-none absolute left-1/2 top-1/2 z-10 -translate-x-1/2 -translate-y-1/2">
          <div className="relative grid size-9 place-items-center rounded-full border border-red-300/60 bg-red-500/20 shadow-[0_0_24px_rgba(239,68,68,.45)]">
            <MapPin className="size-5 text-red-200" />
            <div className="absolute size-14 animate-ping rounded-full border border-red-400/20" />
          </div>
        </div>
        <div className="absolute inset-x-0 bottom-0 flex items-center justify-between bg-slate-950/80 px-3 py-2 text-[10px] text-slate-400 backdrop-blur">
          <span>{label}</span>
          <span>{coords.x}, {coords.y}, {coords.z}</span>
        </div>
      </div>
    </div>
  );
}
