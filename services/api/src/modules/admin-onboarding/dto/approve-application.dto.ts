import { IsOptional, IsString, MaxLength } from 'class-validator';

export class ApproveApplicationDto {
  @IsOptional()
  @IsString()
  @MaxLength(4000)
  reviewNotes?: string;
}
