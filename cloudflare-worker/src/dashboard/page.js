// The page ships as one HTML response: the stylesheet and client script are inlined into
// the markers in dashboard.html. Imported as text via the [[rules]] in wrangler.toml.
import html from "./page/dashboard.html";
import css from "./page/dashboard.css";
import clientJs from "./page/dashboard.client.js";

// Function replacements: a string replacement would expand `$&`-style patterns in the script.
export const DASHBOARD_HTML = html
  .replace("/* dashboard.css */\n", () => css)
  .replace("/* dashboard.client.js */\n", () => clientJs);
