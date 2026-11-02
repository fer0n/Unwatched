import { sendReportEmail } from "./email.js";
import { reportsPage } from "./page.js";
import { blobKey, reportAttachments } from "./report.js";

const MAX_MESSAGE_LENGTH = 10_000;
const MAX_CONTACT_LENGTH = 200;
const MAX_FILE_BYTES = 25 * 1024 * 1024;
const MAX_ATTACHMENTS = 5;
const REPORT_TTL_SECONDS = 180 * 24 * 60 * 60;
const ARCHIVE_TTL_SECONDS = 60 * 24 * 60 * 60;
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
  const attachments = form.getAll("attachment").map(nonEmptyFile).filter(Boolean);
  if (attachments.length > MAX_ATTACHMENTS) {
    return new Response(`At most ${MAX_ATTACHMENTS} attachments`, { status: 400 });
  }
  if ([log, ...attachments].some((file) => file && file.size > MAX_FILE_BYTES)) {
    return new Response("Attachment too large", { status: 413 });
  }
  if (attachments.some((file) => !/^(image|video)\//.test(file.type))) {
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
    attachments: attachments.map((file) => ({ type: file.type, name: file.name.slice(0, 100), size: file.size })),
  };

  const options = { expirationTtl: REPORT_TTL_SECONDS };
  await Promise.all([
    log && env.REPORTS.put(`log:${id}`, log.stream(), options),
    ...attachments.map((file, index) =>
      env.REPORTS.put(`attachment:${id}:${index}`, file.stream(), { ...options, metadata: { type: file.type } }),
    ),
  ]);
  await env.REPORTS.put(`report:${id}`, JSON.stringify(report), options);

  try {
    await sendReportEmail(env, report);
  } catch (error) {
    console.error("Report email failed", error);
  }

  return Response.json({ id }, { status: 201 });
}

export async function handleReportsDashboard(request, url, env) {
  if (url.pathname === "/dashboard/reports" || url.pathname === "/dashboard/reports/archived") {
    const archived = url.pathname.endsWith("/archived");
    const listed = await env.REPORTS.list({ prefix: archived ? "archived:" : "report:", limit: REPORTS_PAGE_SIZE });
    const reports = await Promise.all(listed.keys.map(async (key) => {
      const report = await env.REPORTS.get(key.name, { type: "json" });
      return report && { ...report, expiration: key.expiration };
    }));
    return new Response(reportsPage(reports.filter(Boolean), archived), {
      headers: { "Content-Type": "text/html; charset=utf-8" },
    });
  }

  const action = url.pathname.match(/^\/dashboard\/reports\/([\w-]+)\/(archive|restore)$/);
  if (action) {
    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }
    if (request.headers.get("Origin") !== url.origin) {
      return new Response("Forbidden", { status: 403 });
    }
    const [, id, verb] = action;
    const moved = verb === "archive"
      ? await moveReport(env, id, "report", "archived", ARCHIVE_TTL_SECONDS)
      : await moveReport(env, id, "archived", "report", REPORT_TTL_SECONDS);
    if (!moved) {
      return new Response("Not found", { status: 404 });
    }
    return new Response(null, {
      status: 303,
      headers: { Location: verb === "archive" ? "/dashboard/reports" : "/dashboard/reports/archived" },
    });
  }

  const match = url.pathname.match(/^\/dashboard\/reports\/([\w-]+)\/(log|attachment)(?:\/(\d+))?$/);
  if (!match) {
    return new Response("Not found", { status: 404 });
  }
  const [, id, kind, index] = match;
  const { value, metadata } = await env.REPORTS.getWithMetadata(blobKey(kind, id, index), { type: "stream" });
  if (!value) {
    return new Response("Not found", { status: 404 });
  }
  const contentType = kind === "log" ? "text/plain; charset=utf-8" : (metadata?.type ?? "application/octet-stream");
  return new Response(value, { headers: { "Content-Type": contentType } });
}

async function moveReport(env, id, fromPrefix, toPrefix, ttl) {
  const report = await env.REPORTS.get(`${fromPrefix}:${id}`, { type: "json" });
  if (!report) {
    return false;
  }
  const expiration = Math.floor(Date.now() / 1000) + ttl;
  await env.REPORTS.put(`${toPrefix}:${id}`, JSON.stringify(report), { expiration });
  const keys = [
    ...(report.log ? [blobKey("log", id)] : []),
    ...reportAttachments(report).map(({ index }) => blobKey("attachment", id, index)),
  ];
  await Promise.all(keys.map(async (key) => {
    const { value, metadata } = await env.REPORTS.getWithMetadata(key, { type: "stream" });
    if (value) {
      await env.REPORTS.put(key, value, { expiration, ...(metadata && { metadata }) });
    }
  }));
  await env.REPORTS.delete(`${fromPrefix}:${id}`);
  return true;
}

function nonEmptyFile(value) {
  return value instanceof File && value.size > 0 ? value : null;
}
