import { EmailMessage } from "cloudflare:email";
import { formatBytes } from "./format.js";

const DASHBOARD_URL = "https://signal.octabits.net/dashboard/reports";
const EMAIL_ADDRESS = /^[^\s@<>,;"]+@[^\s@<>,;"]+\.[^\s@<>,;"]+$/;

export async function sendReportEmail(env, report) {
  const subject = `Unwatched report: ${report.appVersion} (${report.build}) · ${report.device} · ${report.os}`;
  const text = [
    report.message,
    "",
    "—",
    `Version: ${report.appVersion} (${report.build}), ${report.channel}`,
    `Device: ${report.device}, ${report.os}`,
    `Reply to: ${report.contact || "not given"}`,
    `Log: ${report.log ? formatBytes(report.log.size) : "not included"}`,
    `Attachments: ${report.attachments.map((file) => `${file.type}, ${formatBytes(file.size)}`).join("; ") || "none"}`,
    "",
    `${DASHBOARD_URL}#${report.id}`,
  ].join("\n");

  const from = env.REPORT_MAIL_FROM;
  const to = env.REPORT_MAIL_TO;
  const raw = mimeMessage({ from, to, subject, text, replyTo: report.contact });
  await env.REPORT_MAIL.send(new EmailMessage(from, to, raw));
}

function mimeMessage({ from, to, subject, text, replyTo }) {
  const headers = [
    `From: Unwatched Reports <${from}>`,
    `To: ${to}`,
    `Subject: ${encodeHeader(subject)}`,
    `Date: ${new Date().toUTCString()}`,
    `Message-ID: <${crypto.randomUUID()}@${from.split("@")[1]}>`,
    "MIME-Version: 1.0",
    "Content-Type: text/plain; charset=utf-8",
    "Content-Transfer-Encoding: base64",
  ];
  if (EMAIL_ADDRESS.test(replyTo)) {
    headers.push(`Reply-To: ${replyTo}`);
  }
  const body = base64(new TextEncoder().encode(text)).replace(/.{76}/g, "$&\r\n");
  return `${headers.join("\r\n")}\r\n\r\n${body}\r\n`;
}

// RFC 2047 caps an encoded word at 75 characters
function encodeHeader(text) {
  const encoder = new TextEncoder();
  const words = [];
  let chunk = "";
  for (const char of text) {
    if (encoder.encode(chunk + char).length > 45) {
      words.push(chunk);
      chunk = "";
    }
    chunk += char;
  }
  words.push(chunk);
  return words.map((word) => `=?UTF-8?B?${base64(encoder.encode(word))}?=`).join("\r\n ");
}

function base64(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary);
}
