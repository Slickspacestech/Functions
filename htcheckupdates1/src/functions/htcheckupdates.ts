import { app, InvocationContext, Timer } from "@azure/functions";
import { runMonitoring } from "../monitor";

app.timer("htcheckupdates1", {
  // Daily at 7:00 AM MDT (UTC-6) = 13:00 UTC
  schedule: "0 0 13 * * *",
  handler: async (myTimer: Timer, context: InvocationContext): Promise<void> => {
    context.log("htcheckupdates1 started");
    if (myTimer.isPastDue) {
      context.warn("Timer is past due — running now");
    }

    const results = await runMonitoring(context);

    const ok = results.filter((r) => r.success).length;
    const updates = results.filter((r) => r.updateAvailable).length;
    const failed = results.filter((r) => !r.success).length;

    context.log(`Done: ${ok} ok, ${updates} update(s) found, ${failed} failed`);
  },
});
