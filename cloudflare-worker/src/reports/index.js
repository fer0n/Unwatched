import { sendReportEmail } from "./email.js";
import { reportsPage } from "./page.js";

const MAX_MESSAGE_LENGTH = 10_000;
const MAX_CONTACT_LENGTH = 200;
const MAX_FILE_BYTES = 25 * 1024 * 1024;
const REPORT_TTL_SECONDS = 180 * 24 * 60 * 60;
const REPORTS_PAGE_SIZE = 50;
const DEVICE_FIELDS = ["appVersion", "build", "channel", "os", "device"];

export function isReportsPath(pathname) {
  return /^\/dashboard\/reports(\/|$)/.test(pathname);
}

export async function handleReportUpload(request, env) {
  let form;
  try {
    form = await request.formData();
  } catch {
    return new Response("Expected multipart/form-data", { status: 400 });
  }

  const message = String(form.get("message") ?? "").trim();
  if (!message) {
    return new Response("Missing 'message'", { status: 400 });
  }
  if (message.length > MAX_MESSAGE_LENGTH) {
    return new Response(`'message' is limited to ${MAX_MESSAGE_LENGTH} characters`, { status: 400 });
  }

  const log = nonEmptyFile(form.get("log"));
  const attachment = nonEmptyFile(form.get("attachment"));
  if ([log, attachment].some((file) => file && file.size > MAX_FILE_BYTES)) {
    return new Response("Attachment too large", { status: 413 });
  }
  if (attachment && !/^(image|video)\//.test(attachment.type)) {
    return new Response("Attachment must be an image or a video", { status: 415 });
  }

  // inverted, so KV lists the newest first
  const id = `${String(1e13 - Date.now()).padStart(13, "0")}-${crypto.randomUUID().slice(0, 8)}`;
  const field = (name, max = 100) => String(form.get(name) ?? "").trim().slice(0, max);
  const report = {
    id,
    createdAt: new Date().toISOString(),
    message,
    contact: field("contact", MAX_CONTACT_LENGTH),
    ...Object.fromEntries(DEVICE_FIELDS.map((name) => [name, field(name) || "unknown"])),
    log: log ? { size: log.size } : null,
    attachment: attachment
      ? { type: attachment.type, name: attachment.name.slice(0, 100), size: attachment.size }
      : null,
  };

  const options = { expirationTtl: REPORT_TTL_SECONDS };
  await Promise.all([
    log && env.REPORTS.put(`log:${id}`, log.stream(), options),
    attachment && env.REPORTS.put(`attachment:${id}`, attachment.stream(), {
      ...options,
      metadata: { type: attachment.type },
    }),
  ]);
  await env.REPORTS.put(`report:${id}`, JSON.stringify(report), options);

  try {
    await sendReportEmail(env, report);
  } catch (error) {
    console.error("Report email failed", error);
  }

  return Response.json({ id }, { status: 201 });
}

export async function handleReportsDashboard(url, env) {
  if (url.pathname === "/dashboard/reports") {
    const listed = await env.REPORTS.list({ prefix: "report:", limit: REPORTS_PAGE_SIZE });
    const reports = await Promise.all(listed.keys.map((key) => env.REPORTS.get(key.name, { type: "json" })));
    return new Response(reportsPage(reports.filter(Boolean)), {
      headers: { "Content-Type": "text/html; charset=utf-8" },
    });
  }

  const match = url.pathname.match(/^\/dashboard\/reports\/([\w-]+)\/(log|attachment)$/);
  if (!match) {
    return new Response("Not found", { status: 404 });
  }
  const [, id, kind] = match;
  const { value, metadata } = await env.REPORTS.getWithMetadata(`${kind}:${id}`, { type: "stream" });
  if (!value) {
    return new Response("Not found", { status: 404 });
  }
  const contentType = kind === "log" ? "text/plain; charset=utf-8" : (metadata?.type ?? "application/octet-stream");
  return new Response(value, { headers: { "Content-Type": contentType } });
}

function nonEmptyFile(value) {
  return value instanceof File && value.size > 0 ? value : null;
}
