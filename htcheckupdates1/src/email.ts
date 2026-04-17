import { getSecret } from "./keyVault";

export interface EmailOptions {
  to: string | string[];
  subject: string;
  body: string;
  html?: boolean;
  sender?: string;
  customHeaders?: Array<{ header: string; value: string }>;
}

export interface EmailSendResult {
  emailId: string;
}

export async function sendEmail(options: EmailOptions): Promise<EmailSendResult> {
  const apiKey = await getSecret("smtp2go-secret");
  const sender = options.sender ?? "patching@huntertech.ca";
  const recipients = Array.isArray(options.to) ? options.to : [options.to];

  const payload: Record<string, unknown> = {
    api_key: apiKey,
    to: recipients,
    sender,
    subject: options.subject,
    [options.html ? "html_body" : "text_body"]: options.body,
  };

  if (options.customHeaders && options.customHeaders.length > 0) {
    payload.custom_headers = options.customHeaders;
  }

  const response = await fetch("https://api.smtp2go.com/v3/email/send", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`SMTP2GO error: ${response.status} - ${errorText}`);
  }

  const result = await response.json() as { data?: { failed?: number; failures?: unknown; email_id?: string } };
  if (result.data?.failed && result.data.failed > 0) {
    throw new Error(`SMTP2GO delivery failed: ${JSON.stringify(result.data.failures)}`);
  }

  return { emailId: result.data?.email_id ?? "" };
}
