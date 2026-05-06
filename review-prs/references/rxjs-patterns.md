# RxJS Patterns Reference

This reference enables the review skill to suggest optimal RxJS patterns based on the actual use case.

---

## 1. Higher-Order Operator Selection

### Decision Tree

```
Is the operation triggered by user action (click, submit, input)?
├── YES: Does order matter?
│   ├── YES: Should we wait for previous to complete?
│   │   ├── YES → concatMap (queue operations)
│   │   └── NO: Should we cancel previous?
│   │       ├── YES → switchMap (typeahead, autocomplete)
│   │       └── NO → exhaustMap (form submit, prevent double-click)
│   └── NO: Can operations run in parallel?
│       └── YES → mergeMap (with concurrency limit)
└── NO: Is it a one-time data fetch?
    └── YES → switchMap or take(1)
```

### Operator Quick Reference

| Operator | When Previous Running | New Value Arrives | Use Case |
|----------|----------------------|-------------------|----------|
| **switchMap** | Cancels previous | Starts new | Search, typeahead, route params |
| **exhaustMap** | Keeps running | Ignores new | Form submit, button click, save |
| **concatMap** | Waits for complete | Queues new | Ordered operations, sequential API |
| **mergeMap** | Keeps running | Starts in parallel | Parallel fetches, file uploads |

---

## 2. Pattern: Search / Typeahead

```typescript
// CORRECT
searchControl.valueChanges.pipe(
  debounceTime(300),                    // Wait for typing pause
  distinctUntilChanged(),               // Skip if same value
  filter(query => query.length >= 2),   // Minimum characters
  switchMap(query => this.searchService.search(query).pipe(
    catchError(() => of([]))            // Error inside switchMap
  )),
  takeUntilDestroyed(this.destroyRef)
).subscribe(results => this.results.set(results));

// WRONG - Common mistakes
searchControl.valueChanges.pipe(
  switchMap(query => this.search(query))  // Missing debounce - floods API
).subscribe();

searchControl.valueChanges.pipe(
  debounceTime(300),
  concatMap(query => this.search(query))  // WRONG - queues all, slow
).subscribe();

searchControl.valueChanges.subscribe(query => {  // WRONG - nested subscribe
  this.search(query).subscribe(results => {});
});
```

---

## 3. Pattern: Form Submit / Button Click

```typescript
// CORRECT - exhaustMap prevents double-submit
submitForm$ = new Subject<void>();

this.submitForm$.pipe(
  exhaustMap(() => {
    this.loading.set(true);
    return this.apiService.save(this.form.value).pipe(
      tap(() => this.toastService.showSuccess('Saved!')),
      catchError(err => {
        this.toastService.showError('Failed to save');
        return EMPTY;
      }),
      finalize(() => this.loading.set(false))
    );
  }),
  takeUntilDestroyed(this.destroyRef)
).subscribe();

// In template: (click)="submitForm$.next()"

// WRONG - switchMap loses requests
saveBtn$.pipe(
  switchMap(() => this.save())  // If user clicks twice fast, first save is cancelled!
).subscribe();

// WRONG - No protection against double-click
save() {
  this.apiService.save(data).subscribe();  // Each click = new request
}
```

---

## 4. Pattern: Parallel API Calls

```typescript
// CORRECT - forkJoin for parallel calls that all must complete
loadDashboard() {
  forkJoin({
    user: this.userService.getUser(),
    settings: this.settingsService.getSettings(),
    notifications: this.notificationService.getRecent()
  }).pipe(
    catchError(err => {
      this.toastService.showError('Failed to load dashboard');
      return EMPTY;
    })
  ).subscribe(({ user, settings, notifications }) => {
    this.user.set(user);
    this.settings.set(settings);
    this.notifications.set(notifications);
  });
}

// CORRECT - mergeMap for parallel processing with concurrency
uploadFiles(files: File[]) {
  from(files).pipe(
    mergeMap(file => this.uploadService.upload(file), 3),  // Max 3 concurrent
    toArray(),
    finalize(() => this.uploading.set(false))
  ).subscribe(results => this.uploadResults.set(results));
}

// WRONG - Sequential when parallel is better
async loadData() {
  const user = await firstValueFrom(this.getUser());      // Waits
  const settings = await firstValueFrom(this.getSettings()); // Then waits
  // Takes 2x as long as forkJoin!
}
```

---

## 5. Pattern: Combining Streams

```typescript
// combineLatest - Emits when ANY source emits (after all have emitted once)
// Use for: filters, derived state from multiple sources
filteredItems$ = combineLatest([
  this.items$,
  this.searchTerm$,
  this.sortOrder$
]).pipe(
  map(([items, search, sort]) =>
    this.filterAndSort(items, search, sort)
  )
);

// withLatestFrom - Emits only when source emits, grabs latest from others
// Use for: action that needs current state
saveItem$.pipe(
  withLatestFrom(this.currentUser$, this.settings$),
  switchMap(([item, user, settings]) =>
    this.api.save({ ...item, userId: user.id, ...settings })
  )
);

// WRONG - combineLatest when withLatestFrom is better
saveBtn$.pipe(
  combineLatest([this.form.valueChanges])  // Emits on EVERY form change!
).subscribe();
```

---

## 6. Pattern: Error Handling

```typescript
// CORRECT - catchError INSIDE switchMap keeps outer stream alive
search$.pipe(
  switchMap(query => this.api.search(query).pipe(
    catchError(err => {
      this.toastService.showError('Search failed');
      return of([]);  // Return fallback, stream continues
    })
  ))
).subscribe();

// CORRECT - Retry with backoff for transient failures
this.api.getData().pipe(
  retry({
    count: 3,
    delay: (error, retryCount) => timer(retryCount * 1000)  // 1s, 2s, 3s
  }),
  catchError(err => {
    this.toastService.showError('Failed after 3 retries');
    return EMPTY;
  })
);

// WRONG - catchError outside kills stream on first error
search$.pipe(
  switchMap(query => this.api.search(query)),
  catchError(() => of([]))  // Stream completes! No more searches work
).subscribe();

// WRONG - Swallowing errors silently
this.api.getData().subscribe({
  next: data => this.data = data,
  // No error handler - errors are silent!
});
```

---

## 7. Pattern: Caching / Sharing

```typescript
// CORRECT - shareReplay for caching HTTP responses
private user$ = this.http.get<User>('/api/user').pipe(
  shareReplay(1)  // Cache latest value, replay to new subscribers
);

// CORRECT - Invalidate cache
private userCache$ = new BehaviorSubject<void>(undefined);
user$ = this.userCache$.pipe(
  switchMap(() => this.http.get<User>('/api/user')),
  shareReplay(1)
);
refreshUser() {
  this.userCache$.next();
}

// WRONG - No sharing, multiple subscribers = multiple HTTP calls
getUser() {
  return this.http.get<User>('/api/user');
}
// component1: this.service.getUser().subscribe()  // HTTP call 1
// component2: this.service.getUser().subscribe()  // HTTP call 2 (duplicate!)
```

---

## 8. Pattern: Loading States

```typescript
// CORRECT - Declarative loading state
private loadTrigger$ = new BehaviorSubject<void>(undefined);

data$ = this.loadTrigger$.pipe(
  tap(() => this.loading.set(true)),
  switchMap(() => this.api.getData().pipe(
    catchError(err => {
      this.error.set(err.message);
      return EMPTY;
    }),
    finalize(() => this.loading.set(false))
  ))
);

// CORRECT - In template with async pipe
@if (loading()) {
  <spinner />
} @else if (error()) {
  <error-message [message]="error()" />
} @else {
  @for (item of data$ | async; track item.id) {
    <item-card [item]="item" />
  }
}

// WRONG - Manual loading state, easy to miss
loadData() {
  this.loading = true;
  this.api.getData().subscribe({
    next: data => {
      this.data = data;
      this.loading = false;
    },
    error: err => {
      // Forgot to set loading = false!
      this.error = err;
    }
  });
}
```

---

## 9. Pattern: Cleanup / Unsubscription

```typescript
// CORRECT - takeUntilDestroyed in constructor (injection context)
constructor() {
  this.data$.pipe(
    takeUntilDestroyed()
  ).subscribe();
}

// CORRECT - takeUntilDestroyed outside injection context
private destroyRef = inject(DestroyRef);

ngOnInit() {
  this.data$.pipe(
    takeUntilDestroyed(this.destroyRef)
  ).subscribe();
}

// CORRECT - Async pipe (auto-unsubscribes)
// template: {{ data$ | async }}

// WRONG - No cleanup
ngOnInit() {
  this.data$.subscribe();  // Memory leak!
}

// WRONG - takeUntilDestroyed without DestroyRef in ngOnInit
ngOnInit() {
  this.data$.pipe(
    takeUntilDestroyed()  // ERROR: not in injection context
  ).subscribe();
}
```

---

## 10. Pattern: Subject vs Signal

```typescript
// Use SIGNAL for:
// - Component state
// - Derived/computed values
// - Simple state that doesn't need stream operators

// CORRECT - Signal for component state
items = signal<Item[]>([]);
selectedItem = signal<Item | null>(null);
itemCount = computed(() => this.items().length);

// Use SUBJECT for:
// - Event streams that need RxJS operators
// - Integration with existing Observable-based APIs
// - Complex async flows

// CORRECT - Subject for action streams
private saveAction$ = new Subject<Item>();
private deleteAction$ = new Subject<string>();

// Connect to effects
this.saveAction$.pipe(
  exhaustMap(item => this.api.save(item)),
  takeUntilDestroyed()
).subscribe();

// WRONG - BehaviorSubject when Signal is simpler
private items$ = new BehaviorSubject<Item[]>([]);
get items() { return this.items$.value; }
setItems(items: Item[]) { this.items$.next(items); }
// Just use: items = signal<Item[]>([]);
```

---

## 11. Anti-Pattern Detection

### Nested Subscribes
```typescript
// WRONG
this.user$.subscribe(user => {
  this.orders$.subscribe(orders => {
    this.process(user, orders);
  });
});

// CORRECT
combineLatest([this.user$, this.orders$]).pipe(
  takeUntilDestroyed()
).subscribe(([user, orders]) => {
  this.process(user, orders);
});
```

### Subscribe to Set Property
```typescript
// WRONG
ngOnInit() {
  this.data$.subscribe(data => this.data = data);
}
// template: {{ data.name }}

// CORRECT - Use async pipe
// template: {{ (data$ | async)?.name }}
// Or with @if:
@if (data$ | async; as data) {
  {{ data.name }}
}
```

### Promise When Observable Works
```typescript
// WRONG - Converting to promise loses reactivity
async loadData() {
  this.data = await firstValueFrom(this.api.getData());
}

// CORRECT - Stay reactive
data$ = this.api.getData().pipe(shareReplay(1));
```

---

## 12. Review Checklist

| Pattern | Check |
|---------|-------|
| Search/typeahead | switchMap + debounceTime + distinctUntilChanged |
| Form submit | exhaustMap (prevent double-submit) |
| Button click | exhaustMap or take(1) |
| Parallel calls | forkJoin or mergeMap with concurrency |
| Sequential calls | concatMap |
| Error handling | catchError INSIDE switchMap |
| Caching | shareReplay(1) |
| Loading state | finalize() to reset |
| Cleanup | takeUntilDestroyed or async pipe |
| Combining | combineLatest for derived, withLatestFrom for actions |
| Simple state | Signal, not BehaviorSubject |
