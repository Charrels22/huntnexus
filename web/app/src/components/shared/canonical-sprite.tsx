import { useMemo, useState } from "react";
import { ImageOff } from "lucide-react";

export type CanonicalSpriteKind = "creature" | "item";

function fileNameFromDisplayName(name: string) {
  return `${name.trim().replaceAll(" ", "_")}.gif`;
}

function tibiaWikiFileRedirect(fileName: string) {
  return `https://www.tibiawiki.com.br/wiki/Especial:Redirect/file/${encodeURIComponent(fileName)}`;
}

export function CanonicalSprite({
  kind,
  name,
  alt,
  className = "",
  size = "md",
}: {
  kind: CanonicalSpriteKind;
  name: string | null | undefined;
  alt?: string;
  className?: string;
  size?: "sm" | "md" | "lg";
}) {
  const [failed, setFailed] = useState(false);
  const url = useMemo(() => {
    if (!name) return null;
    return tibiaWikiFileRedirect(fileNameFromDisplayName(name));
  }, [name]);

  const dimensions = size === "sm" ? "size-12" : size === "lg" ? "size-24" : "size-16";

  if (!url || failed) {
    return (
      <div
        className={`${dimensions} ${className} grid shrink-0 place-items-center rounded-xl border border-white/8 bg-slate-950/70`}
        title={name || "Asset indisponível"}
      >
        <ImageOff className="size-4 text-slate-700" />
      </div>
    );
  }

  return (
    <div
      className={`${dimensions} ${className} grid shrink-0 place-items-center overflow-hidden rounded-xl border border-white/8 bg-slate-950/75`}
      title={`${kind === "creature" ? "Criatura" : "Item"} — visual canônico`}
    >
      <img
        src={url}
        alt={alt || name || ""}
        loading="lazy"
        decoding="async"
        className="max-h-[90%] max-w-[90%] object-contain [image-rendering:pixelated]"
        onError={() => setFailed(true)}
      />
    </div>
  );
}

export function CanonicalSpriteGroup({
  names,
}: {
  names: Array<string | null | undefined>;
}) {
  const clean = names.filter((x): x is string => Boolean(x)).slice(0, 4);
  return (
    <div className="flex items-end justify-center -space-x-3">
      {clean.map((name, index) => (
        <CanonicalSprite
          key={name}
          kind="creature"
          name={name}
          size="lg"
          className={`transition duration-300 hover:-translate-y-2 hover:scale-110 hover:z-10 ${index % 2 ? "translate-y-3" : ""}`}
        />
      ))}
    </div>
  );
}
