import { IsOptional, IsString, Length } from 'class-validator';

export class UpsertBusinessDto {
  @IsString()
  legalName!: string;

  @IsOptional()
  @IsString()
  tradingName?: string;

  @IsOptional()
  @IsString()
  registrationNumber?: string;

  @IsOptional()
  @IsString()
  taxId?: string;

  @IsOptional()
  @IsString()
  addressLine1?: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsString()
  @Length(2, 2)
  countryCode!: string;

  @IsOptional()
  @IsString()
  websiteUrl?: string;
}
