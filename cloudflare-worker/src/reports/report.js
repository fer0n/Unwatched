// reports from before multiple attachments keep their single one at `attachment:<id>`, without an index
export function blobKey(kind, id, index) {
  return index === undefined ? `${kind}:${id}` : `${kind}:${id}:${index}`;
}

export function reportAttachments(report) {
  if (report.attachments) {
    return report.attachments.map((file, index) => ({ type: file.type, index }));
  }
  return report.attachment ? [{ type: report.attachment.type, index: undefined }] : [];
}
