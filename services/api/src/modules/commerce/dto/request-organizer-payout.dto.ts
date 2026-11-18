import { IsOptional, IsString, MaxLength } from 'class-validator';

export class RequestOrganizerPayoutDto {
  @IsOptional()
  @IsString()
  @MaxLength(32)
  accountNumber?: string;

  @IsOptional()
  @IsString()
  @MaxLength(16)
  bankCode?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  accountName?: string;
}
