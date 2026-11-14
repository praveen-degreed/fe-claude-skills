import { inject } from '@angular/core';
import { forkJoin } from 'rxjs';

const MAX_PAGES = 20;

export class AudienceService {
  private readonly api = inject(ApiService);

  loadAll(id: string) {
    let page = 1;
    const out = [];
    while (page <= MAX_PAGES) {
      const res = this.api.getAccessList(id, page);
      out.push(...res.items);
      if (!res.hasNextPage) break;
      page++;
    }
    return out;
  }

  apply(deletes: string[]) {
    return forkJoin(deletes.map((d) => this.api.remove(d)));
  }
}
