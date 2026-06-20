import { IsArray, IsInt, IsOptional, IsString, Min, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';

export class TicketOrderLineDto {
  @IsString()
  tierId!: string;

  @IsInt()
  @Min(1)
  quantity!: number;
}

export class CreateTicketOrderDto {
  @IsOptional()
  @IsString()
  attendeeId?: string;

  @IsString()
  currency!: string;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => TicketOrderLineDto)
  items!: TicketOrderLineDto[];
}
