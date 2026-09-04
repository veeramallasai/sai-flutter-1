package com.farmtohome.api.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

public final class PasswordSetupDtos {
  private PasswordSetupDtos() {}

  public record SendRequest(
      @NotBlank(message = "Email is required")
      @Email(message = "Enter a valid email address")
      String email
  ) {}

  public record CompleteRequest(
      @NotBlank(message = "Email is required")
      @Email(message = "Enter a valid email address")
      String email,

      @NotBlank(message = "OTP is required")
      @Pattern(regexp = "\\d{6}", message = "OTP must be 6 digits")
      String otp,

      @NotBlank(message = "Password is required")
      @Size(min = 8, message = "Password must be at least 8 characters")
      String password
  ) {}

  public record LoginRequest(
      @NotBlank(message = "Email is required")
      String email,

      @NotBlank(message = "Password is required")
      String password
  ) {}

  public record RegisterRequest(
      @NotBlank(message = "First name is required")
      String firstName,
      String lastName,
      @NotBlank(message = "Email is required")
      @Email(message = "Enter a valid email address")
      String email,
      String phoneNumber,
      @NotBlank(message = "Password is required")
      @Size(min = 8, message = "Password must be at least 8 characters")
      String password,
      String role
  ) {}
}
