import { Injectable } from '@nestjs/common';

type Labels = Record<string, string>;

@Injectable()
export class MetricsService {
  private readonly counters = new Map<string, number>();

  inc(name: string, labels: Labels = {}, amount = 1): void {
    const key = this.key(name, labels);
    this.counters.set(key, (this.counters.get(key) ?? 0) + amount);
  }

  renderPrometheus(): string {
    const lines: string[] = [];
    for (const [key, value] of this.counters.entries()) {
      const { name, labels } = this.parseKey(key);
      const labelStr = Object.entries(labels)
        .map(([k, v]) => `${k}="${v.replace(/"/g, '\\"')}"`)
        .join(',');
      lines.push(`# TYPE ${name} counter`);
      lines.push(labelStr ? `${name}{${labelStr}} ${value}` : `${name} ${value}`);
    }
    lines.push('# TYPE owanbe_up gauge');
    lines.push('owanbe_up 1');
    return `${lines.join('\n')}\n`;
  }

  snapshot(): Record<string, number> {
    const out: Record<string, number> = {};
    for (const [key, value] of this.counters.entries()) {
      out[key] = value;
    }
    return out;
  }

  private key(name: string, labels: Labels): string {
    const sorted = Object.keys(labels)
      .sort()
      .map((k) => `${k}=${labels[k]}`)
      .join(',');
    return sorted ? `${name}|${sorted}` : name;
  }

  private parseKey(key: string): { name: string; labels: Labels } {
    const [name, labelPart] = key.split('|');
    const labels: Labels = {};
    if (labelPart) {
      for (const pair of labelPart.split(',')) {
        const [k, v] = pair.split('=');
        if (k && v) labels[k] = v;
      }
    }
    return { name, labels };
  }
}
