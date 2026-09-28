-- Phase C/W2b: OTP codes are stored HASHED (sha256(phone:code)); the
-- plaintext only ever lives in the SMS provider call and the (non-production)
-- devCode response.
ALTER TABLE "OtpCode" RENAME COLUMN "code" TO "codeHash";
