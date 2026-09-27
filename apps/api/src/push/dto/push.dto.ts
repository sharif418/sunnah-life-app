// Push DTOs (Task B2) — Bengali-first validation messages, Swagger examples.
import { ApiProperty } from "@nestjs/swagger";
import { IsIn, IsNotEmpty, IsString, Length, MaxLength } from "class-validator";

export class RegisterPushTokenDto {
  @ApiProperty({
    description: "FCM registration token",
    example: "dKs8fQ…(opaque FCM token)…9x",
  })
  @IsString({ message: "ডিভাইস টোকেন দিন" })
  @IsNotEmpty({ message: "ডিভাইস টোকেন দিন" })
  @Length(64, 512, { message: "ডিভাইস টোকেনটি সঠিক নয়" })
  token!: string;

  @ApiProperty({ enum: ["android", "ios"], example: "android" })
  @IsIn(["android", "ios"], { message: "প্ল্যাটফর্ম android বা ios হতে হবে" })
  platform!: string;
}

export class UnregisterPushTokenDto {
  @ApiProperty({ example: "dKs8fQ…(opaque FCM token)…9x" })
  @IsString({ message: "ডিভাইস টোকেন দিন" })
  @IsNotEmpty({ message: "ডিভাইস টোকেন দিন" })
  @MaxLength(512)
  token!: string;
}
