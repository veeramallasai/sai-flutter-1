package com.farmtohome.api.auth;

import com.farmtohome.api.common.ApiResponse;
import jakarta.validation.Valid;
import java.security.Principal;
import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/auth")
public class PasswordSetupController {
  private final PasswordSetupService service;

  public PasswordSetupController(PasswordSetupService service) {
    this.service = service;
  }

  @PostMapping("/password-setup/send")
  public ApiResponse<Map<String, Object>> sendOtp(@Valid @RequestBody PasswordSetupDtos.SendRequest request) {
    return ApiResponse.ok(service.send(request.email()), "OTP sent. Check your Gmail inbox.");
  }

  @PostMapping("/password-setup/complete")
  public ApiResponse<Map<String, Object>> complete(@Valid @RequestBody PasswordSetupDtos.CompleteRequest request) {
    return ApiResponse.ok(
        service.complete(request.email(), request.otp(), request.password()),
        "Password setup completed successfully.");
  }

  @PostMapping("/login")
  public ApiResponse<Map<String, Object>> login(@Valid @RequestBody PasswordSetupDtos.LoginRequest request) {
    return ApiResponse.ok(service.login(request.email(), request.password()), "Logged in successfully.");
  }

  @PostMapping("/register")
  public ApiResponse<Map<String, Object>> register(@Valid @RequestBody PasswordSetupDtos.RegisterRequest request) {
    return ApiResponse.ok(
        service.register(
            request.firstName(),
            request.lastName(),
            request.email(),
            request.phoneNumber(),
            request.password(),
            request.role()),
        "Account created successfully.");
  }

  @GetMapping("/me")
  public ApiResponse<Map<String, Object>> me(Principal principal) {
    if (principal == null || principal.getName() == null) {
      return ApiResponse.ok(Map.of("authenticated", false));
    }
    return ApiResponse.ok(Map.of(
        "authenticated", true,
        "userId", principal.getName()
    ));
  }
}
