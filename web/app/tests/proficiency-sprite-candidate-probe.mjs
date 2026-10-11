import { chromium } from "playwright";

const candidates = [
  "Proficiency Spell Eternal Winter.gif",
  "Proficiency Spell Heal Friend.gif",
  "Proficiency Spell Ice Burst.gif",
  "Proficiency Spell Strong Ice Wave.gif",
  "Proficiency Spell Terra Wave.gif",
  "Proficiency Spell Devastating Knockout.gif",
  "Proficiency Spell Executioners Throw.gif",
  "Proficiency Spell Executioner\'s Throw.gif",
  "Proficiency Type Perc Auto Atk Magic.gif",
  "Proficiency Type Damage.gif",
  "Proficiency Augment Damage.gif",
  "Proficiency Augment Healing.gif",
];

const browser = await chromium.launch({ headless:true });
try {
  const page = await browser.newPage();
  await page.goto("https://huntnexus.charr3ls22.workers.dev/profile", {waitUntil:"domcontentloaded",timeout:30000});
  const results = await page.evaluate(async (files) => {
    const wiki = (name) =>
      "https://www.tibiawiki.com.br/wiki/Special:Redirect/file/" + encodeURIComponent(name).replace(/%20/g,"_");
    const load = (name) => new Promise((resolve) => {
      const image = new Image();
      let finished = false;
      const done = (loaded) => {
        if (finished) return;
        finished = true;
        resolve({ file:name,loaded,width:image.naturalWidth,height:image.naturalHeight });
      };
      image.onload = () => done(true);
      image.onerror = () => done(false);
      image.src = wiki(name);
      setTimeout(() => done(false), 14000);
    });
    const rows = [];
    for (let start=0;start<files.length;start+=3) {
      rows.push(...await Promise.all(files.slice(start,start+3).map(load)));
    }
    return rows;
  }, candidates);
  console.log(JSON.stringify({
    status:"ok",stage:"candidate_tibiawiki_proficiency_sprite_url_probe_v1",
    candidates_checked:results.length,available:results.filter(r=>r.loaded).length,
    every_candidate_grounded_in_game_client:false,
    results,
  },null,2));
} finally {
  await browser.close();
}
