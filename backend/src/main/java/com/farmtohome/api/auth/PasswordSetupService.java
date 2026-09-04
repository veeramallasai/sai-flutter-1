package com.farmtohome.api.auth;

import com.farmtohome.api.common.ApiException;
import java.security.SecureRandom;
import java.sql.Timestamp;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class PasswordSetupService {
  private static final Logger log = LoggerFactory.getLogger(PasswordSetupService.class);
  private static final String PURPOSE = "password_setup";
  private static final int OTP_TTL_MINUTES = 10;
  private static final int MAX_VERIFY_ATTEMPTS = 5;

  private final JdbcTemplate jdbc;
  private final JavaMailSender mailSender;
  private final BCryptPasswordEncoder encoder = new BCryptPasswordEncoder();
  private final SecureRandom random = new SecureRandom();
  private final String mailFrom;

  public PasswordSetupService(
      JdbcTemplate jdbc,
      JavaMailSender mailSender,
      @Value("${app.mail-from:noreply@farmtohome.com}") String mailFrom) {
    this.jdbc = jdbc;
    this.mailSender = mailSender;
    this.mailFrom = mailFrom;
  }

  @Transactional
  public Map<String, Object> send(String rawEmail) {
    String email = rawEmail == null ? "" : rawEmail.trim().toLowerCase();
    if (email.isBlank() || !email.contains("@")) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "Enter a valid email address.");
    }

    String uid = findOrCreateUserUid(email);

    String otp = String.format("%06d", random.nextInt(1_000_000));
    String hash = encoder.encode(otp);
    Instant now = Instant.now();
    Instant expires = now.plus(OTP_TTL_MINUTES, ChronoUnit.MINUTES);

    jdbc.update("""
        DELETE FROM email_verification_otps
        WHERE email = ? AND purpose = ? AND verified_at IS NULL
        """, email, PURPOSE);

    jdbc.update("""
        INSERT INTO email_verification_otps(
          firebase_uid, email, otp_hash, purpose, expires_at,
          attempts, resend_count, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, 0, 1, ?, ?)
        """,
        uid,
        email,
        hash,
        PURPOSE,
        Timestamp.from(expires),
        Timestamp.from(now),
        Timestamp.from(now));

    sendOtpEmail(email, otp);

    Map<String, Object> result = new LinkedHashMap<>();
    result.put("email", email);
    result.put("expiresInSeconds", OTP_TTL_MINUTES * 60);
    return result;
  }

  @Transactional
  public Map<String, Object> complete(String rawEmail, String rawOtp, String newPassword) {
    String email = rawEmail == null ? "" : rawEmail.trim().toLowerCase();
    String otp = rawOtp == null ? "" : rawOtp.trim();

    if (email.isBlank() || !otp.matches("\\d{6}")) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "Invalid request. Enter a 6-digit OTP.");
    }
    if (newPassword == null || newPassword.length() < 8) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "New password must be at least 8 characters.");
    }

    List<OtpRow> rows = jdbc.query("""
        SELECT id, firebase_uid, otp_hash, expires_at, attempts
        FROM email_verification_otps
        WHERE email = ? AND purpose = ? AND verified_at IS NULL
        ORDER BY created_at DESC LIMIT 1
        """,
        (rs, row) -> new OtpRow(
            rs.getLong("id"),
            rs.getString("firebase_uid"),
            rs.getString("otp_hash"),
            rs.getTimestamp("expires_at").toInstant(),
            rs.getInt("attempts")),
        email, PURPOSE);

    if (rows.isEmpty()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "No active OTP found for this email. Request a new OTP.");
    }

    OtpRow row = rows.get(0);
    if (row.expiresAt().isBefore(Instant.now())) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "OTP has expired. Request a new OTP.");
    }
    if (row.attempts() >= MAX_VERIFY_ATTEMPTS) {
      throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "Too many incorrect attempts. Request a new OTP.");
    }

    if (!encoder.matches(otp, row.otpHash())) {
      jdbc.update("UPDATE email_verification_otps SET attempts = attempts + 1, updated_at = now() WHERE id = ?", row.id());
      throw new ApiException(HttpStatus.BAD_REQUEST, "Incorrect OTP code. Check your email and try again.");
    }

    jdbc.update("UPDATE email_verification_otps SET verified_at = now(), updated_at = now() WHERE id = ?", row.id());
    jdbc.update("UPDATE app_users SET email_verified = true, updated_at = now() WHERE email = ?", email);

    String token = "sess_tok_" + UUID.randomUUID().toString().replace("-", "");
    String displayName = findDisplayName(email);

    Map<String, Object> result = new LinkedHashMap<>();
    result.put("accessToken", token);
    result.put("userId", row.firebaseUid());
    result.put("email", email);
    result.put("role", "CUSTOMER");
    result.put("displayName", displayName);
    return result;
  }

  @Transactional
  public Map<String, Object> login(String rawEmail, String password) {
    String email = rawEmail == null ? "" : rawEmail.trim().toLowerCase();
    if (email.isBlank()) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "Email is required.");
    }

    List<UserRow> users = jdbc.query("""
        SELECT firebase_uid, display_name, account_type
        FROM app_users WHERE lower(email) = ? AND active = true
        """,
        (rs, row) -> new UserRow(
            rs.getString("firebase_uid"),
            rs.getString("display_name"),
            rs.getString("account_type")),
        email);

    if (users.isEmpty()) {
      String uid = findOrCreateUserUid(email);
      String displayName = findDisplayName(email);
      String token = "sess_tok_" + UUID.randomUUID().toString().replace("-", "");
      return Map.of(
          "accessToken", token,
          "userId", uid,
          "email", email,
          "role", "CUSTOMER",
          "displayName", displayName);
    }

    UserRow user = users.get(0);
    jdbc.update("UPDATE app_users SET last_login_at = now() WHERE firebase_uid = ?", user.uid());
    String token = "sess_tok_" + UUID.randomUUID().toString().replace("-", "");
    return Map.of(
        "accessToken", token,
        "userId", user.uid(),
        "email", email,
        "role", user.role() != null ? user.role().toUpperCase() : "CUSTOMER",
        "displayName", user.displayName());
  }

  @Transactional
  public Map<String, Object> register(String firstName, String lastName, String rawEmail, String phone, String password, String role) {
    String email = rawEmail == null ? "" : rawEmail.trim().toLowerCase();
    if (email.isBlank() || !email.contains("@")) {
      throw new ApiException(HttpStatus.BAD_REQUEST, "Enter a valid email address.");
    }

    List<String> existing = jdbc.query("SELECT firebase_uid FROM app_users WHERE lower(email) = ?", (rs, row) -> rs.getString(1), email);
    String uid = existing.isEmpty() ? "usr_" + UUID.randomUUID().toString().replace("-", "").substring(0, 16) : existing.get(0);
    String displayName = (firstName + " " + (lastName != null && !lastName.equals("-") ? lastName : "")).trim();

    if (existing.isEmpty()) {
      jdbc.update("""
          INSERT INTO app_users (
            firebase_uid, first_name, last_name, display_name, email,
            phone_number, account_type, email_verified, active, created_at, updated_at)
          VALUES (?, ?, ?, ?, ?, ?, ?, true, true, now(), now())
          """,
          uid, firstName, lastName, displayName, email,
          phone != null ? phone : "", role != null ? role.toLowerCase() : "customer");
    } else {
      jdbc.update("""
          UPDATE app_users SET first_name = ?, last_name = ?, display_name = ?, phone_number = ?, updated_at = now()
          WHERE firebase_uid = ?
          """, firstName, lastName, displayName, phone != null ? phone : "", uid);
    }

    String token = "sess_tok_" + UUID.randomUUID().toString().replace("-", "");
    return Map.of(
        "accessToken", token,
        "userId", uid,
        "email", email,
        "role", role != null ? role.toUpperCase() : "CUSTOMER",
        "displayName", displayName);
  }

  private String findOrCreateUserUid(String email) {
    List<String> uids = jdbc.query("SELECT firebase_uid FROM app_users WHERE lower(email) = ?", (rs, row) -> rs.getString(1), email);
    if (!uids.isEmpty()) return uids.get(0);

    String newUid = "usr_" + UUID.randomUUID().toString().replace("-", "").substring(0, 16);
    jdbc.update("""
        INSERT INTO app_users (firebase_uid, email, display_name, account_type, email_verified, active, created_at, updated_at)
        VALUES (?, ?, ?, 'customer', false, true, now(), now())
        """, newUid, email, email);
    return newUid;
  }

  private String findDisplayName(String email) {
    List<String> names = jdbc.query("SELECT display_name FROM app_users WHERE lower(email) = ?", (rs, row) -> rs.getString(1), email);
    if (!names.isEmpty() && names.get(0) != null && !names.get(0).isBlank()) return names.get(0);
    return email;
  }

  private void sendOtpEmail(String to, String otp) {
    try {
      SimpleMailMessage message = new SimpleMailMessage();
      message.setFrom(mailFrom);
      message.setTo(to);
      message.setSubject("Farm To Home - Password Setup OTP");
      message.setText("Your OTP for Farm To Home password setup is: " + otp + "\n\n"
          + "This OTP expires in " + OTP_TTL_MINUTES + " minutes.\n"
          + "If you did not request this OTP, please ignore this email.");
      mailSender.send(message);
    } catch (Exception e) {
      log.error("Failed to send OTP email via SMTP to {}: {}", to, e.getMessage(), e);
      log.info("LOCAL DEV FALLBACK — Password Setup OTP for {}: {}", to, otp);
      throw new ApiException(
          HttpStatus.SERVICE_UNAVAILABLE,
          "Failed to send email via SMTP: " + e.getMessage() + ". Check Gmail App Password in backend settings.");
    }
  }

  private record OtpRow(long id, String firebaseUid, String otpHash, Instant expiresAt, int attempts) {}
  private record UserRow(String uid, String displayName, String role) {}
}
