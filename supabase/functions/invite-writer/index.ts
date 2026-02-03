import "jsr:@supabase/functions-js/edge-runtime.d.ts";

Deno.serve(async (req) => {
  try {
    const body = await req.json();

    const language = body.language ?? "en"; // 'en' | 'sv'
    const activity = body.activity ?? "walk"; // 'walk' | 'coffee' | 'workout' | 'lunch' | 'dinner'
    const duration = body.duration ?? 20; // minutes
    const meetingTime = body.meeting_time ?? null;
    const place = body.place ?? null;

    const activitySv = activity === "walk"
      ? "promenad"
      : activity === "coffee"
      ? "fika"
      : activity === "workout"
      ? "träning"
      : activity === "lunch"
      ? "lunch"
      : "middag";
    const activityEn = activity === "walk"
      ? "walk"
      : activity === "coffee"
      ? "fika"
      : activity === "workout"
      ? "workout"
      : activity === "lunch"
      ? "lunch"
      : "dinner";

    const suggestions =
      language === "sv"
        ? [
            `Hej! Tänkte ta en lugn ${duration}-minuters ${activitySv}. Inga krav på prat. Vill du följa med?${meetingTime ? ` Tid: ${meetingTime}.` : ""}${place ? ` Plats: ${place}.` : ""}`,
            `Tjena! Jag kör en kort ${activitySv} (${duration} min). Låg press, vi kan vara tysta. Hänger du på?${meetingTime ? ` Tid: ${meetingTime}.` : ""}${place ? ` Plats: ${place}.` : ""}`,
            `Hej! Om du vill: ${duration} min ${activitySv} i lugn takt. Vill du ses?${meetingTime ? ` Tid: ${meetingTime}.` : ""}${place ? ` Plats: ${place}.` : ""}`,
          ]
        : [
            `Hey! I’m up for a quiet ${duration}-minute ${activityEn}. No pressure to talk. Want to join?${meetingTime ? ` Time: ${meetingTime}.` : ""}${place ? ` Place: ${place}.` : ""}`,
            `Hi! Quick ${activityEn} for ${duration} minutes—low pressure, we can stay quiet. Interested?${meetingTime ? ` Time: ${meetingTime}.` : ""}${place ? ` Place: ${place}.` : ""}`,
            `Hey! ${duration} min ${activityEn}, calm pace. Want to meet?${meetingTime ? ` Time: ${meetingTime}.` : ""}${place ? ` Place: ${place}.` : ""}`,
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
