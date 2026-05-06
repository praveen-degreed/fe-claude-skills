# Degreed FE Workspace - Service & Pattern Standards

This reference defines the correct usage of common services. The fe-impact-analyzer agent should validate PRs against these patterns.

---

## 1. AUTH / USER SERVICES

### AuthService
**Location:** `@degreed/lxp/services/authorization`
**Injection:** `inject(AuthService)`

```typescript
// CORRECT
const orgName = this.authService.authUser?.defaultOrgInfo?.name || 'Degreed';
const userId = this.authService.authUser?.viewerProfile?.userProfileKey;
const permissions = this.authService.authUser?.permissions;

// WRONG - Don't access nested without null checks
const orgName = this.authService.authUser.defaultOrgInfo.name; // Can crash
```

**Key Properties:**
- `authUser` - Full user object (AuthUser)
- `authUser.viewerProfile` - User profile info
- `authUser.defaultOrgInfo` - Organization info
- `authUser.permissions` - User permissions

---

## 2. ENVIRONMENT SERVICES

### WebEnvironmentService
**Location:** `@degreed/lxp/services`
**Injection:** `inject(WebEnvironmentService)`

```typescript
// CORRECT - Always use getBlobUrl for asset URLs
const imageUrl = this.webEnvService.getBlobUrl(relativePath);
const staticUrl = this.webEnvService.getBlobUrl(path, true); // isStatic = true

// WRONG - Don't hardcode blob URLs
const imageUrl = 'https://blob.degreed.com/' + path;

// WRONG - Don't use relative paths directly in templates
<img [src]="item.imageUrl"> // May not resolve correctly
```

**Key Methods:**
- `getBlobUrl(url, isStatic?)` - Convert to blob URL
- `getBlobBaseUrl()` - Get blob base
- `environment` - Environment config
- `isProduction` - Production check

---

## 3. TRANSLATION / I18N

### TranslateService with translateWithDefaults
**Location:** `@degreed/core/utils`
**Pattern:**

```typescript
// CORRECT - Use translateWithDefaults helper
import { translateWithDefaults, TranslateFn } from '@degreed/core/utils';

private translate: TranslateFn = translateWithDefaults(inject(TranslateService));

// Usage
const message = this.translate('Default text', 'i18n_Key');
const withParams = this.translate('Hello {name}', 'i18n_Greeting', { name: 'User' });

// WRONG - Don't use inline strings
<button>Submit</button> // Not translatable

// CORRECT
<button>{{ 'Submit' | dgxTranslate:'Button_Submit' }}</button>
```

### DgxTranslatePipe
**Location:** `@degreed/core/pipes`
**Usage:** `{{ 'Default' | dgxTranslate:'Key' }}`

---

## 4. NOTIFICATIONS

### ToastService (Apollo)
**Location:** `@degreed/apollo`
**Injection:** `inject(ToastService)`

```typescript
// CORRECT
this.toastService.showToast('Success!', { type: 'success' });
this.toastService.showToast('Error occurred', {
  type: 'error',
  autoClose: false // Keep error visible
});

// WRONG - Don't use alert() or console for user messages
alert('Error!');
```

### NotifierService (Wrapper)
**Location:** `@degreed/lxp/services`

```typescript
// CORRECT
this.notifierService.showError('Error message');
this.notifierService.showSuccess('Success!');
this.notifierService.showWarning('Warning');
```

---

## 5. DIALOGS / DRAWERS

### DrawerService (Modern - Preferred)
**Location:** `@degreed/apollo`
**Injection:** `inject(DrawerService)`

```typescript
// CORRECT
const drawerRef = this.drawerService.open(MyComponent, {
  config: { title: 'Edit Item' },
  inputs: { data: myData }
});

// MUST handle close
drawerRef.afterClosed().subscribe(result => {
  if (result.type === 'save') {
    // Handle save
  }
});

// WRONG - Not subscribing to afterClosed
this.drawerService.open(MyComponent, { ... }); // Result ignored!
```

### DialogService (Deprecated)
**Note:** Use DrawerService instead for new code.

---

## 6. HTTP PATTERNS

### NgxHttpClient
**Location:** `@degreed/lxp/services`
**Injection:** `inject(NgxHttpClient)`

```typescript
// CORRECT - Auto-prefixes /api, handles casing
this.http.get<User>('users/123').pipe(
  catchAndSurfaceError('Failed to load user')
).subscribe(...);

// CORRECT - With error context
this.http.get<Data>('endpoint', {
  context: new HttpContext()
    .set(HANDLE_ERROR, true)
    .set(HANDLE_ERROR_MESSAGE, 'Custom error')
});

// WRONG - Don't use raw HttpClient for API calls
this.httpClient.get('/api/users/123'); // Missing error handling, casing

// WRONG - Missing error handling
this.http.get<Data>('endpoint').subscribe(data => ...); // No error handler!
```

**Error Handling Pattern:**
```typescript
import { catchAndSurfaceError } from '@degreed/lxp/services';

this.http.get<T>('endpoint').pipe(
  catchAndSurfaceError('Error loading data') // Shows toast on error
);
```

---

## 7. STATE MANAGEMENT

### ReactiveStore (RSM Pattern)
**Location:** `@degreed/lxp/services`

```typescript
// CORRECT - Use store pattern for complex state
export class MyStore extends ReactiveStore<MyState, MyEntity> {
  constructor() {
    super(initialState);
  }
}

// CORRECT - Use selectors
this.store.entities$.pipe(...);
this.store.isLoading$.pipe(...);
```

### Signals (Modern Pattern)
```typescript
// CORRECT - Use signals for local state
private items = signal<Item[]>([]);
public readonly items$ = this.items.asReadonly();
public itemCount = computed(() => this.items().length);

// WRONG - Don't mix signals and BehaviorSubjects for same state
private items = signal([]);
private items$ = new BehaviorSubject([]); // Redundant!
```

---

## 8. SUBSCRIPTION CLEANUP

### takeUntilDestroyed (Preferred)
```typescript
// CORRECT
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';

constructor() {
  this.data$.pipe(
    takeUntilDestroyed()
  ).subscribe(...);
}

// WRONG - Manual unsubscribe without cleanup
ngOnInit() {
  this.subscription = this.data$.subscribe(...);
}
// Missing ngOnDestroy cleanup!
```

### Async Pipe (Best for Templates)
```typescript
// CORRECT - Auto-unsubscribes
@if (data$ | async; as data) {
  {{ data.name }}
}

// WRONG - Manual subscription in component for template data
this.data$.subscribe(d => this.data = d); // Memory leak risk
```

---

## 9. ACCESSIBILITY SERVICES

### A11yService (Apollo)
**Location:** `@degreed/apollo`
**Injection:** `inject(A11yService)`

```typescript
// CORRECT - For modals/drawers
this.a11yService.setInertState(true);  // When opening
this.a11yService.setInertState(false); // When closing
this.a11yService.moveFocusToElement('element-id');
```

### DfFocusStackService (Fresco)
```typescript
// CORRECT - Save and restore focus
this.focusStack.push(); // Before opening modal
// ... modal interaction ...
this.focusStack.pop();  // After closing - restores focus
```

---

## 10. FEATURE FLAGS

### LDFlagsService
**Location:** `@degreed/lxp/services`
**Injection:** `inject(LDFlagsService)`

```typescript
// CORRECT
if (this.ldFlagsService.isEnabled('my-feature-flag')) {
  // New feature
}

// CORRECT - Grouped flags
if (this.ldFlagsService.profile.newDashboard) {
  // ...
}

// WRONG - Hardcoded feature toggles
const enableFeature = true; // Should use feature flags
```

---

## 11. COMMON UTILITIES

### Location: `@degreed/core/utils`

```typescript
// String utilities
import { camelCaseKeys, generateGuid, startCase } from '@degreed/core/utils';

// Object utilities
import { deepEqual, deepMerge, getDeepCopy } from '@degreed/core/utils';

// Array utilities
import { sortBy, groupBy, orderBy } from '@degreed/core/utils';

// URL utilities
import { isUrlAbsolute, safeEncodeURIComponent } from '@degreed/core/utils';
```

---

## 12. PIPES

### BlobifyUrlPipe
**Location:** `@degreed/lxp/services`

```html
<!-- CORRECT -->
<img [src]="imageUrl | blobifyUrl">
<img [src]="staticUrl | blobifyUrl:true">

<!-- WRONG -->
<img [src]="imageUrl"> <!-- May not resolve blob URLs -->
```

---

## VALIDATION CHECKLIST

When reviewing PRs, check:

| Pattern | Correct Usage | Common Mistakes |
|---------|--------------|-----------------|
| **Auth** | `authService.authUser?.prop` | Missing null checks |
| **Assets** | `webEnvService.getBlobUrl()` | Hardcoded URLs |
| **i18n** | `translateWithDefaults()` or pipe | Inline strings |
| **Toasts** | `toastService.showToast()` | Using alert() |
| **Drawers** | Subscribe to `afterClosed()` | Ignoring close result |
| **HTTP** | `catchAndSurfaceError()` | Missing error handling |
| **State** | Signals or ReactiveStore | Mixing patterns |
| **Cleanup** | `takeUntilDestroyed()` | Manual subscriptions |
| **Flags** | `ldFlagsService.isEnabled()` | Hardcoded toggles |
