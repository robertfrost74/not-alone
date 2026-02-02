import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req) => {
  try {
    const body = await req.json();

    const language = body.language ?? "en"; // 'en' | 'sv'
    const activity = body.activity ?? "walk"; // 'walk' | 'coffee' | 'codo'
    const duration = body.duration ?? 20; // minutes

    const activitySv =
      activity === "walk" ? "promenad" : activity === "coffee" ? "kaffe" : "co-do";
    const activityEn =
      activity === "walk" ? "walk" : activity === "coffee" ? "coffee" : "co-do";

    const suggestions =
      language === "sv"
        ? [
            `Hej! Tänkte ta en lugn ${duration}-minuters ${activitySv}. Inga krav på prat. Vill du följa med?`,
            `Tjena! Jag kör en kort ${activitySv} (${duration} min). Låg press, vi kan vara tysta. Hänger du på?`,
            `Hej! Om du vill: ${duration} min ${activitySv} i lugn takt. Vill du ses?`,
          ]
        : [
            `Hey! I’m up for a quiet ${duration}-minute ${activityEn}. No pressure to talk. Want to join?`,
            `Hi! Quick ${activityEn} for ${duration} minutes—low pressure, we can stay quiet. Interested?`,
            `Hey! ${duration} min ${activityEn}, calm pace. Want to meet?`,
          ];

    return new Response(JSON.stringify({ ok: true, suggestions }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
});
