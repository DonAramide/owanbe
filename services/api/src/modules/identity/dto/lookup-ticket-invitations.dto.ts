import { IsBoolean, IsOptional, IsString } from 'class-validator';

export class LookupTicketInvitationsDto {
  @IsOptional()
  @IsString()
  email?: string;

  @IsOptional()
  @IsString()
  phone?: string;
}
