import { IsOptional, IsString, Length, Matches } from 'class-validator';

export class CreateVendorDto {
  @IsString()
  businessName!: string;

  @IsString()
  @Matches(/^[a-z0-9]+(?:-[a-z0-9]+)*$/, {
    message: 'slug must be lowercase URL-safe',
  })
  slug!: string;

  @IsString()
  @Length(2, 2)
  countryCode!: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsString()
  description?: string;
}
