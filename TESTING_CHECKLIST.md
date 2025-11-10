# ✅ TESTING CHECKLIST - LOGIN & REGISTRATION FIXES

## Pre-Testing Setup

- [ ] Device has internet connection
- [ ] Flutter is installed and up to date
- [ ] Android Studio / Xcode is available
- [ ] Device/Emulator is ready

---

## TEST 1: Empty Fields (UT-02) ✅

### Test Case 1.1: Empty Email
```
Steps:
  1. Open app → Tap "Sign in"
  2. Leave Email field EMPTY
  3. Enter Password: "password123"
  4. Tap "Sign in"

Expected Result:
  ✅ Alert Dialog appears immediately
  ✅ Title: "Validation Error"
  ✅ Message: "Please enter both email and password"
  ✅ Button: "OK"
  ✅ Error sound plays
  ✅ No loading overlay shown
  ✅ User stays on login screen
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

### Test Case 1.2: Empty Password
```
Steps:
  1. Open Login Screen
  2. Enter Email: "test@email.com"
  3. Leave Password field EMPTY
  4. Tap "Sign in"

Expected Result:
  ✅ Alert Dialog appears immediately
  ✅ Message: "Please enter both email and password"
  ✅ Error sound plays
  ✅ NOT attempting Firebase login
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

### Test Case 1.3: Both Fields Empty
```
Steps:
  1. Open Login Screen
  2. Leave both Email and Password EMPTY
  3. Tap "Sign in"

Expected Result:
  ✅ Alert Dialog appears immediately
  ✅ Message: "Please enter both email and password"
  ✅ Error sound plays
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

---

## TEST 2: Invalid Email Format ✅

### Test Case 2.1: Email without @
```
Steps:
  1. Open Login Screen
  2. Enter Email: "notanemail"
  3. Enter Password: "password123"
  4. Tap "Sign in"

Expected Result:
  ✅ Alert Dialog appears immediately
  ✅ Message: "Please enter a valid email address"
  ✅ Error sound plays
  ✅ NOT attempting Firebase login
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

### Test Case 2.2: Email with @ but incomplete
```
Steps:
  1. Open Login Screen
  2. Enter Email: "test@"
  3. Enter Password: "password123"
  4. Tap "Sign in"

Expected Result:
  ✅ Alert Dialog appears
  ✅ Message: "Please enter a valid email address"
  ✅ Error sound plays
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

---

## TEST 3: Invalid Credentials (UT-03) ✅

### Test Case 3.1: Wrong Password
```
Steps:
  1. Enable internet connection
  2. Open Login Screen
  3. Enter Email: "user@email.com" (existing account)
  4. Enter Password: "wrongpassword"
  5. Tap "Sign in"

Expected Result:
  ✅ Loading overlay appears ("Signing in...")
  ✅ After ~2 seconds: Overlay disappears
  ✅ Error message displayed: "Invalid email or password"
  ✅ Message is NOT a Firebase error code
  ✅ Error sound plays
  ✅ User can retry immediately
  ✅ User stays on login screen
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

### Test Case 3.2: Email Not Registered
```
Steps:
  1. Enable internet connection
  2. Open Login Screen
  3. Enter Email: "nonexistent@email.com"
  4. Enter Password: "anypassword"
  5. Tap "Sign in"

Expected Result:
  ✅ Loading overlay appears
  ✅ After ~2 seconds: Error message
  ✅ Message: "Invalid email or password" (NOT "user not found")
  ✅ Error sound plays
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

---

## TEST 4: No Internet Warning ✅

### Test Case 4.1: Airplane Mode ON
```
Steps:
  1. Enable Airplane Mode on device
  2. Open Login Screen
  3. Enter Email: "test@email.com"
  4. Enter Password: "password123"
  5. Tap "Sign in"

Expected Result:
  ✅ Alert Dialog appears within 5 seconds
  ✅ Title: "Validation Error"
  ✅ Message: "No internet connection. Please check your network and try again."
  ✅ Error sound plays immediately
  ✅ NO loading overlay shown
  ✅ NO Firebase call attempted
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

### Test Case 4.2: WiFi & Mobile Disabled
```
Steps:
  1. Turn OFF WiFi
  2. Turn OFF Mobile Data
  3. Open Login Screen
  4. Enter Email: "test@email.com"
  5. Enter Password: "password123"
  6. Tap "Sign in"

Expected Result:
  ✅ Alert Dialog appears within 5 seconds
  ✅ Message about no internet connection
  ✅ Error sound plays
  ✅ User can enable internet and retry
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

---

## TEST 5: Short Password ✅

### Test Case 5.1: Password Less Than 6 Characters
```
Steps:
  1. Open Register Screen
  2. Enter Email: "newuser@email.com"
  3. Enter Password: "pass" (less than 6 chars)
  4. Enter Confirm: "pass"
  5. Tap "Create account"

Expected Result:
  ✅ Alert Dialog appears
  ✅ Message: "Password must be at least 6 characters"
  ✅ Error sound plays
  ✅ NOT attempting Firebase registration
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

---

## TEST 6: Password Mismatch (Registration) ✅

### Test Case 6.1: Register with Mismatched Passwords
```
Steps:
  1. Open Register Screen
  2. Enter Email: "newuser@email.com"
  3. Enter Password: "password123"
  4. Enter Confirm Password: "password456"
  5. Tap "Create account"

Expected Result:
  ✅ Alert Dialog appears
  ✅ Message: "Passwords do not match"
  ✅ Error sound plays
  ✅ NOT attempting Firebase registration
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

---

## TEST 7: Successful Login ✅

### Test Case 7.1: Valid Credentials, Internet ON
```
Steps:
  1. Ensure internet is enabled
  2. Open Login Screen
  3. Enter registered Email: "verified@email.com"
  4. Enter correct Password: "password123"
  5. Tap "Sign in"

Expected Result:
  ✅ Loading overlay appears ("Signing in...")
  ✅ After ~2-3 seconds: Overlay disappears
  ✅ Success sound plays
  ✅ App navigates to Home Screen (or Email Verification if not verified)
  ✅ NO error message shown
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

---

## TEST 8: Registration Success ✅

### Test Case 8.1: Valid New Account
```
Steps:
  1. Ensure internet is enabled
  2. Open Register Screen
  3. Enter Email: "newuser123@email.com" (not registered)
  4. Enter Password: "SecurePass123"
  5. Enter Confirm: "SecurePass123"
  6. Tap "Create account"

Expected Result:
  ✅ Loading overlay appears
  ✅ After ~3 seconds: Success sound plays
  ✅ App navigates to Email Verification screen
  ✅ Message about verification link sent
  ✅ User can click "Resend verification link"
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

---

## TEST 9: Forgot Password ✅

### Test Case 9.1: Valid Email
```
Steps:
  1. Ensure internet is enabled
  2. Open Forgot Password Screen
  3. Enter Email: "registered@email.com"
  4. Tap "Send reset link"

Expected Result:
  ✅ Loading overlay appears
  ✅ After ~2 seconds: Success sound plays
  ✅ App navigates to Reset Password Sent screen
  ✅ Message shows email where reset link was sent
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

### Test Case 9.2: No Internet
```
Steps:
  1. Enable Airplane Mode
  2. Open Forgot Password Screen
  3. Enter Email: "registered@email.com"
  4. Tap "Send reset link"

Expected Result:
  ✅ Alert Dialog appears within 5 seconds
  ✅ Message: "No internet connection..."
  ✅ Error sound plays
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

---

## TEST 10: Sound Effects ✅

### Test Case 10.1: Error Sound
```
Steps:
  1. Open Login Screen
  2. Leave email empty
  3. Tap "Sign in"

Expected Result:
  ✅ Error sound plays immediately
  ✅ Sound is clearly audible
  ✅ Sound is appropriate for error
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

### Test Case 10.2: Success Sound
```
Steps:
  1. Open Forgot Password Screen
  2. Enter valid registered email
  3. Ensure internet is ON
  4. Tap "Send reset link"

Expected Result:
  ✅ Success sound plays after Firebase response
  ✅ Sound is clearly audible
  ✅ Sound is appropriate for success
  
Status: [ ] PASS [ ] FAIL
Notes: ___________________________________
```

---

## SUMMARY RESULTS

### Overall Test Results
```
Total Tests: [ ] / [ ] PASSED
Pass Rate: [ ]%

Critical Issues: [ ]
Major Issues: [ ]
Minor Issues: [ ]

Recommendation: [ ] APPROVED [ ] NEEDS FIXES
```

### Issues Found
```
1. ____________________________________________________
   Severity: [ ] CRITICAL [ ] MAJOR [ ] MINOR
   Steps to Reproduce: ______________________________
   
2. ____________________________________________________
   Severity: [ ] CRITICAL [ ] MAJOR [ ] MINOR
   Steps to Reproduce: ______________________________

3. ____________________________________________________
   Severity: [ ] CRITICAL [ ] MAJOR [ ] MINOR
   Steps to Reproduce: ______________________________
```

### Tester Information
```
Tester Name: ________________
Date: ______________________
Device Model: ______________
Android/iOS Version: ________
App Version: ________________
Internet Provider: __________
```

---

## NOTES FOR DEVELOPER

```
Additional observations:
________________________________________________
________________________________________________
________________________________________________
________________________________________________
```

---

## APPROVAL SIGNATURES

Developer: ________________________  Date: ______
QA Tester: ________________________  Date: ______
Project Lead: ______________________  Date: ______

---

**All tests should PASS ✅**  
**If any test fails, please report the issue with steps to reproduce.**
