import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RejectApplicationDto {
  @IsString()
  @MinLength(1)
  @MaxLength(4000)
  rejectionReason!: string;

  @IsOptional()
  @IsString()
  @MaxLength(4000)
  reviewNotes?: string;
}
