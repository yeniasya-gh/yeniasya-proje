/**
 * Example CDN-side password reset service.
 *
 * Expected routes:
 * - POST /auth/password-reset/request
 * - POST /auth/password-reset/confirm
 *
 * Install example deps:
 *   npm i express pg
 *
 * Required env vars:
 *   DATABASE_URL=postgres://...
 *   MAIL_API_URL=https://cdn.yeniasyadijital.com/mail/send
 *   MAIL_API_TOKEN=...
 *   RESET_WEB_URL=https://cdn.yeniasyadijital.com/sifre-sifirla
 *   PASSWORD_RESET_TOKEN_TTL_MINUTES=30
 *
 * Security notes:
 * - Return the same success body whether the email exists or not.
 * - Store only token hashes, never raw tokens.
 * - Enforce IP/email rate limits.
 * - Mark tokens single-use and expire them quickly.
 * - This example keeps compatibility with the current app's SHA-256 password hashing.
 *   Migrate to a stronger password hash algorithm separately when login/auth can be updated.
 */

import crypto from "node:crypto";
import express from "express";
import { Pool } from "pg";

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const router = express.Router();

const MAIL_API_URL =
  process.env.MAIL_API_URL || "https://cdn.yeniasyadijital.com/mail/send";
const MAIL_API_TOKEN = process.env.MAIL_API_TOKEN || "";
const RESET_WEB_URL =
  process.env.RESET_WEB_URL || "https://cdn.yeniasyadijital.com/sifre-sifirla";
const TOKEN_TTL_MINUTES = Number.parseInt(
  process.env.PASSWORD_RESET_TOKEN_TTL_MINUTES || "30",
  10,
);

const genericRequestResponse = {
  ok: true,
  message:
    "Bu e-posta adresi kayıtlıysa şifre sıfırlama bağlantısı gönderildi.",
};

const rateLimitStore = new Map();

function normalizeEmail(value) {
  return String(value || "").trim().toLowerCase();
}

function sha256Hex(value) {
  return crypto.createHash("sha256").update(value, "utf8").digest("hex");
}

function createRawToken() {
  return crypto.randomBytes(32).toString("base64url");
}

function currentPasswordHash(password) {
  return sha256Hex(password);
}

function validatePassword(password) {
  const value = String(password || "").trim();
  if (value.length < 8) {
    return "Sifre en az 8 karakter olmali.";
  }
  if (!/[A-Z]/.test(value)) {
    return "Sifre en az 1 buyuk harf icermeli.";
  }
  if (!/[a-z]/.test(value)) {
    return "Sifre en az 1 kucuk harf icermeli.";
  }
  if (!/[0-9]/.test(value)) {
    return "Sifre en az 1 rakam icermeli.";
  }
  return null;
}

function getClientIp(req) {
  const forwarded = req.headers["x-forwarded-for"];
  if (typeof forwarded === "string" && forwarded.trim()) {
    return forwarded.split(",")[0].trim();
  }
  return req.ip || req.socket?.remoteAddress || "unknown";
}

function enforceRateLimit(key, limit, windowMs) {
  const now = Date.now();
  const existing = rateLimitStore.get(key);
  const next = (existing || []).filter((ts) => now - ts < windowMs);
  if (next.length >= limit) {
    const retryAfterSec = Math.ceil((windowMs - (now - next[0])) / 1000);
    const error = new Error("RATE_LIMIT");
    error.statusCode = 429;
    error.retryAfterSec = retryAfterSec;
    throw error;
  }
  next.push(now);
  rateLimitStore.set(key, next);
}

async function sendResetEmail({ to, name, resetLink }) {
  if (!MAIL_API_TOKEN) {
    throw new Error("MAIL_API_TOKEN is missing.");
  }

  const html = `
    <div style="font-family:Arial,sans-serif;background:#fafafa;padding:16px;">
      <div style="max-width:640px;margin:0 auto;background:#fff;border-radius:10px;padding:20px;">
        <h1 style="color:#d32f2f;margin-top:0;">Yeni Asya Dijital</h1>
        <p>Merhaba ${escapeHtml(name)},</p>
        <p>Sifrenizi sifirlamak icin asagidaki baglantiya tiklayin:</p>
        <p style="margin:16px 0;">
          <a href="${resetLink}" style="background:#d32f2f;color:#fff;padding:10px 16px;border-radius:8px;text-decoration:none;">
            Sifreyi Sifirla
          </a>
        </p>
        <p>Bu baglanti tek kullanimliktir ve ${TOKEN_TTL_MINUTES} dakika gecerlidir.</p>
        <p>Baglanti calismazsa su adresi kopyalayin:<br><small>${resetLink}</small></p>
      </div>
    </div>
  `;

  const response = await fetch(MAIL_API_URL, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-mail-token": MAIL_API_TOKEN,
    },
    body: JSON.stringify({
      to,
      fromName: "Yeni Asya Dijital",
      from_name: "Yeni Asya Dijital",
      subject: "Sifre sifirlama talebiniz",
      text: `Merhaba ${name}, sifrenizi sifirlamak icin bu adresi kullanin: ${resetLink}`,
      html,
    }),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new Error(`MAIL_SEND_FAILED (${response.status}): ${body}`);
  }
}

function escapeHtml(value) {
  return String(value || "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

router.post("/auth/password-reset/request", express.json(), async (req, res) => {
  try {
    const email = normalizeEmail(req.body?.email);
    const ip = getClientIp(req);

    enforceRateLimit(`reset-request:ip:${ip}`, 8, 15 * 60 * 1000);
    if (email) {
      enforceRateLimit(`reset-request:email:${email}`, 3, 15 * 60 * 1000);
    }

    if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      return res.status(200).json(genericRequestResponse);
    }

    const userResult = await pool.query(
      `
        select id, name, email
        from public.users
        where lower(email) = $1
          and is_active = true
        limit 1
      `,
      [email],
    );

    if (userResult.rowCount === 0) {
      return res.status(200).json(genericRequestResponse);
    }

    const user = userResult.rows[0];
    const rawToken = createRawToken();
    const tokenHash = sha256Hex(rawToken);
    const expiresAt = new Date(Date.now() + TOKEN_TTL_MINUTES * 60 * 1000);
    const client = await pool.connect();

    try {
      await client.query("begin");
      await client.query(
        `
          update public.password_reset_tokens
          set used_at = now()
          where user_id = $1
            and used_at is null
        `,
        [user.id],
      );
      await client.query(
        `
          insert into public.password_reset_tokens (
            user_id,
            token_hash,
            expires_at,
            requested_ip,
            user_agent
          )
          values ($1, $2, $3, $4, $5)
        `,
        [
          user.id,
          tokenHash,
          expiresAt.toISOString(),
          ip,
          String(req.headers["user-agent"] || "").slice(0, 512),
        ],
      );
      await client.query("commit");
    } catch (error) {
      await client.query("rollback");
      throw error;
    } finally {
      client.release();
    }

    const resetLink = `${RESET_WEB_URL}?token=${encodeURIComponent(rawToken)}&email=${encodeURIComponent(user.email)}`;
    await sendResetEmail({
      to: user.email,
      name: user.name || user.email,
      resetLink,
    });

    return res.status(200).json(genericRequestResponse);
  } catch (error) {
    if (error.statusCode === 429) {
      return res
        .status(429)
        .set("Retry-After", String(error.retryAfterSec || 60))
        .json({
          ok: false,
          message: "Cok fazla deneme yapildi. Lutfen daha sonra tekrar deneyin.",
        });
    }
    console.error("[password-reset/request]", error);
    return res.status(500).json({
      ok: false,
      message: "Sifre sifirlama istegi su anda islenemiyor.",
    });
  }
});

router.post("/auth/password-reset/confirm", express.json(), async (req, res) => {
  try {
    const token = String(req.body?.token || "").trim();
    const password = String(req.body?.password || "");
    const ip = getClientIp(req);

    enforceRateLimit(`reset-confirm:ip:${ip}`, 10, 15 * 60 * 1000);

    const passwordError = validatePassword(password);
    if (!token || passwordError) {
      return res.status(400).json({
        ok: false,
        message: passwordError || "Sifirlama baglantisi gecersiz.",
      });
    }

    const tokenHash = sha256Hex(token);
    const client = await pool.connect();

    try {
      await client.query("begin");
      const tokenResult = await client.query(
        `
          select prt.id, prt.user_id, prt.expires_at
          from public.password_reset_tokens prt
          join public.users u on u.id = prt.user_id
          where prt.token_hash = $1
            and prt.used_at is null
            and u.is_active = true
          for update
        `,
        [tokenHash],
      );

      if (tokenResult.rowCount === 0) {
        await client.query("rollback");
        return res.status(400).json({
          ok: false,
          message: "Sifirlama baglantisi gecersiz veya daha once kullanildi.",
        });
      }

      const tokenRow = tokenResult.rows[0];
      if (new Date(tokenRow.expires_at).getTime() < Date.now()) {
        await client.query("rollback");
        return res.status(410).json({
          ok: false,
          message: "Sifirlama baglantisinin suresi dolmus.",
        });
      }

      const nextPasswordHash = currentPasswordHash(password);
      await client.query(
        `
          update public.users
          set password = $1
          where id = $2
        `,
        [nextPasswordHash, tokenRow.user_id],
      );
      await client.query(
        `
          update public.password_reset_tokens
          set used_at = now()
          where user_id = $1
            and used_at is null
        `,
        [tokenRow.user_id],
      );
      await client.query("commit");
    } catch (error) {
      await client.query("rollback");
      throw error;
    } finally {
      client.release();
    }

    return res.status(200).json({
      ok: true,
      message: "Sifre basariyla guncellendi.",
    });
  } catch (error) {
    if (error.statusCode === 429) {
      return res
        .status(429)
        .set("Retry-After", String(error.retryAfterSec || 60))
        .json({
          ok: false,
          message: "Cok fazla deneme yapildi. Lutfen daha sonra tekrar deneyin.",
        });
    }
    console.error("[password-reset/confirm]", error);
    return res.status(500).json({
      ok: false,
      message: "Sifre guncellenemedi.",
    });
  }
});

export default router;
