// MediaWiki file titles are case-sensitive beyond the first letter.
// Analyzer loot names are lower-case (e.g. "blue crystal shard"), whereas
// the confirmed canonical asset is "Blue_Crystal_Shard.gif".
const minorWords = new Set(["a", "an", "and", "at", "by", "for", "from", "in", "of", "on", "or", "the", "to", "with"]);

export function canonicalSpriteFileName(displayName: string): string {
  const cleaned = displayName.trim().replace(/\s+/g, " ").replace(/\.gif$/i, "");
  if (!cleaned) return "";
  const words = cleaned.replace(/_/g, " ").split(" ");
  return words.map((word, index) => {
    const lowered = word.toLocaleLowerCase("en-US");
    if (index > 0 && minorWords.has(lowered)) return lowered;
    return lowered.charAt(0).toUpperCase() + lowered.slice(1);
  }).join("_") + ".gif";
}

export function canonicalSpriteRedirect(displayName: string): string | null {
  const file = canonicalSpriteFileName(displayName);
  if (!file) return null;
  return "https://www.tibiawiki.com.br/wiki/Especial:Redirect/file/" + encodeURIComponent(file);
}
