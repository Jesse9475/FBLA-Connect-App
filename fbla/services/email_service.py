"""
Email delivery service.

Uses Python's built-in smtplib — no extra packages required.

Configure via environment variables (add to .env):

  SMTP_HOST   — e.g. smtp.gmail.com  (default: smtp.gmail.com)
  SMTP_PORT   — e.g. 587             (default: 587, TLS)
  SMTP_USER   — your Gmail / SMTP address
  SMTP_PASS   — Gmail App Password (or SMTP password)
  SMTP_FROM   — display name + address, e.g. "FBLA Connect <no-reply@example.com>"
                defaults to SMTP_USER if not set

Gmail quick-start:
  1. Enable 2-Step Verification on your Google account
  2. Go to myaccount.google.com → Security → App passwords
  3. Generate a 16-char app password for "Mail"
  4. Add to .env:
       SMTP_USER=youraddress@gmail.com
       SMTP_PASS=xxxx xxxx xxxx xxxx
"""

import logging
import smtplib
import ssl
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from flask import current_app

logger = logging.getLogger(__name__)


def _cfg(key: str, default: str = "") -> str:
    return current_app.config.get(key) or default


def send_otp_email(to_email: str, code: str) -> bool:
    """
    Send a 6-digit OTP to *to_email*.

    Returns True on success, False if SMTP is not configured or sending fails.
    Failures are logged but never raise — the caller decides what to do.
    """
    host = _cfg("SMTP_HOST", "smtp.gmail.com")
    port = int(_cfg("SMTP_PORT", "587"))
    user = _cfg("SMTP_USER")
    password = _cfg("SMTP_PASS")

    if not user or not password:
        logger.warning(
            "send_otp_email: SMTP_USER / SMTP_PASS not set — email not sent. "
            "Add them to your .env to enable real email delivery."
        )
        return False

    from_addr = _cfg("SMTP_FROM") or user
    subject = "Your FBLA Connect verification code"

    # ── HTML body ────────────────────────────────────────────────────────────
    html = f"""\
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background:#070D1F;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background:#070D1F;padding:40px 20px;">
    <tr>
      <td align="center">
        <table width="480" cellpadding="0" cellspacing="0"
               style="background:#0D1829;border-radius:16px;border:1px solid #1E3054;overflow:hidden;">

          <!-- Header -->
          <tr>
            <td style="background:linear-gradient(135deg,#001561,#012B83,#226ADD);padding:32px;text-align:center;">
              <div style="display:inline-block;background:rgba(245,166,35,0.15);
                          border:1px solid rgba(245,166,35,0.4);border-radius:12px;
                          padding:10px 20px;margin-bottom:16px;">
                <span style="color:#F5A623;font-size:13px;font-weight:700;letter-spacing:2px;">FBLA CONNECT</span>
              </div>
              <h1 style="margin:0;color:#ffffff;font-size:24px;font-weight:800;">Verify your email</h1>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:32px;text-align:center;">
              <p style="color:#8BA3C7;font-size:15px;margin:0 0 28px;">
                Enter this code in the app to confirm your email address.
                It expires in&nbsp;<strong style="color:#E8EFF9;">5&nbsp;minutes</strong>.
              </p>

              <!-- OTP code box -->
              <div style="display:inline-block;background:#111F35;border:2px solid #F5A623;
                          border-radius:14px;padding:20px 48px;margin-bottom:28px;">
                <span style="color:#F5A623;font-size:42px;font-weight:900;
                             letter-spacing:12px;font-variant-numeric:tabular-nums;">
                  {code}
                </span>
              </div>

              <p style="color:#8BA3C7;font-size:13px;margin:0 0 8px;">
                Didn&rsquo;t request this? You can safely ignore this email.
              </p>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background:#070D1F;padding:20px 32px;text-align:center;
                       border-top:1px solid #1E3054;">
              <p style="color:#4A6490;font-size:12px;margin:0;">
                &copy; 2026 FBLA Connect &mdash; Future Business Leaders of America
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""

    # Plain-text fallback
    text = f"Your FBLA Connect verification code is: {code}\n\nIt expires in 5 minutes."

    # ── Build message ────────────────────────────────────────────────────────
    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = from_addr
    msg["To"] = to_email
    msg.attach(MIMEText(text, "plain"))
    msg.attach(MIMEText(html, "html"))

    # ── Send ─────────────────────────────────────────────────────────────────
    try:
        context = ssl.create_default_context()
        with smtplib.SMTP(host, port, timeout=10) as smtp:
            smtp.ehlo()
            smtp.starttls(context=context)
            smtp.login(user, password)
            smtp.sendmail(from_addr, to_email, msg.as_string())
        logger.info("send_otp_email: sent OTP to %s", to_email)
        return True
    except smtplib.SMTPAuthenticationError:
        logger.error(
            "send_otp_email: SMTP authentication failed for %s — "
            "check SMTP_USER / SMTP_PASS in .env. "
            "For Gmail, make sure you're using an App Password, not your account password.",
            user,
        )
    except smtplib.SMTPException as exc:
        logger.error("send_otp_email: SMTP error sending to %s: %s", to_email, exc)
    except OSError as exc:
        logger.error("send_otp_email: network error sending to %s: %s", to_email, exc)
    return False
