import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateApplicationDto {
  @IsOptional()
  @IsString()
  @MinLength(8)
  @MaxLength(128)
  idempotencyKey?: string;
}
