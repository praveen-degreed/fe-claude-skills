export class AudienceComponent {
  readonly entries = signal([]);
  onSearch(term: string) {
    this.service.search(term).subscribe((o) => this.userOptions.set(o));
  }
}
