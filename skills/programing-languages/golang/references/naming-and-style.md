# Go Naming and Style Reference

Sources: [Go Style Guide](https://google.github.io/styleguide/go/guide), [Style Decisions](https://google.github.io/styleguide/go/decisions), [Best Practices](https://google.github.io/styleguide/go/best-practices), [Identifier Naming](https://testing.googleblog.com/2017/10/code-health-identifiernamingpostforworl.html)

---

## Document Relationships

| Document | Status | Purpose |
|---|---|---|
| **Guide** | Normative / canonical | Core principles; earlier overrides later when in conflict |
| **Decisions** | Non-canonical elaboration | Specific rulings on recurring questions |
| **Best Practices** | Explicitly non-canonical | Optional patterns worth knowing |

Local consistency never overrides a documented principle. If a file uses an idiosyncratic pattern, adopt the principle, not the local habit.

---

## Readability Priority Hierarchy

When principles conflict, earlier ones win:

1. **Clarity** — purpose and rationale are obvious to the reader
2. **Simplicity** — accomplishes goals in the simplest possible way
3. **Concision** — high signal-to-noise ratio
4. **Maintainability** — easy to modify correctly over time
5. **Consistency** — aligns with the broader codebase

Code is read far more than it is written. Optimise for the reader.

---

## Naming

### Casing

Use `MixedCaps` for exported identifiers and `mixedCaps` for unexported ones. Never use `snake_case` or `ALL_CAPS`.

```go
// Bad
const MAX_PACKET_SIZE = 1024
const kMaxPacketSize = 1024

// Good
const MaxPacketSize = 1024
```

### Receiver Names

- 1–2 characters, an abbreviation of the type name
- Consistent across **all** methods of the type
- Use `_` only if the receiver is genuinely unused

```go
// Bad
func (tray Tray) Add(item Item) { … }

// Good
func (t Tray) Add(item Item) { … }
```

### Package Names

- Lowercase, single word, no underscores
- Never pluralised (`httputil`, not `httputils`)
- Never generic: no `util`, `common`, `helper`, `misc`
- Multi-word packages concatenate without separator: `tabwriter`, not `tab_writer`

### Getters — No `Get` Prefix

A method that returns a value does not need a `Get` prefix. Reserve `Fetch` or `Compute` for operations with meaningful cost.

```go
// Bad
func (c *Counter) GetCounts() int { … }

// Good
func (c *Counter) Counts() int { … }
```

### Initialisms

Maintain uniform case for the entire initialism. Exportedness determines the case of the first letter, but every letter of the initialism follows suit.

```go
// Bad
type XmlApi struct { … }
userUrl := …
httpHandler := …

// Good
type XMLAPI struct { … }   // exported
xmlAPI := …                 // unexported
userURL := …
httpHandler := …
```

Common initialisms: `URL`, `ID`, `DB`, `HTTP`, `API`, `RPC`, `TLS`.  
Mixed-case words like `gRPC` and `iOS` follow exportedness: exported → `GRPC`/`IOS`, unexported → `gRPC`/`iOS`.

### Constants

Name constants by what they **mean**, not what their value is. Use `MixedCaps`.

```go
// Bad
const MAX_PACKET_SIZE = 1024
const kMaxSize = 1024

// Good
const MaxPacketSize = 1024
```

### Avoid Stutter

Do not repeat the package name, type name, or obvious context in an identifier.

```go
// Bad — package already provides context
widget.NewWidget()

// Good
widget.New()
```

```go
// Bad — receiver type is visible at every call site
func (tray Tray) AddItemToTray(item Item) { … }

// Good
func (t Tray) Add(item Item) { … }
```

### Scope-Proportional Length

Name length should be proportional to scope size and inversely proportional to use frequency.

- **Package / exported identifiers**: long, fully descriptive — encode units, semantics, and context that callers cannot see. `GetElapsedFrameTimeSecs` over `GetTime`; `MaxPacketSize` over `Size`.
- **Function-level variables**: single word is the baseline. `count`, `options`, `result`.
- **Tight local scopes** (loop indices, short closures): single letters are idiomatic. `i`, `r`, `b`.

Omit words the scope already implies:

```go
// Bad — inside UserCount(), "user" is obvious
userCount := 0

// Good
count := 0
```

When a name encodes units or domain meaning that would otherwise be ambiguous, keep it regardless of length: `timeoutSecs`, `offsetBytes`, `retryIntervalMillis`.

---

## Error Conventions

### Error Strings

Lowercase, no trailing punctuation. They compose into larger messages and mid-sentence capitalisation looks wrong.

```go
// Bad
return fmt.Errorf("Something went wrong.")

// Good
return fmt.Errorf("something went wrong")
```

Exception: proper nouns, exported identifiers, and initialisms retain their capitalisation (`fmt.Errorf("URL %q is invalid", u)`).

### Sentinel Errors and Error Types

```go
var ErrNotFound = errors.New("not found")   // sentinel: ErrFoo
type ValidationError struct { … }            // error type: FooError
```

`error` is always the last return value.

### Wrapping: `%w` vs `%v`

| Verb | When to use |
|---|---|
| `%w` | Preserving the original error for programmatic inspection (`errors.Is`/`errors.As`) — use inside the application |
| `%v` | Logging, display, or at system boundaries (RPC, IPC, storage) where callers should not depend on the wrapped type |

Place `%w` last in the format string: `"context: %w"`.  
Add only **new** context; do not repeat what the wrapped error already says.

```go
// Bad — redundant
return fmt.Errorf("open file failed: file open error: %w", err)

// Good
return fmt.Errorf("open settings: %w", err)
```

### No In-Band Error Signalling

Never return a sentinel value like `-1` or `""` to signal an error. Return `(value, error)` or `(value, bool)`.

```go
// Bad
func Find(s []string, target string) int { // returns -1 on miss

// Good
func Find(s []string, target string) (int, bool)
```

---

## Control Flow and Formatting

### Error Path First

Check errors (and other early-exit conditions) before the happy path. This keeps the main logic unindented and readable top-to-bottom. Avoid `else` after a terminal branch.

```go
// Bad
if err == nil {
    // happy path — deeply nested
} else {
    return err
}

// Good
if err != nil {
    return err
}
// happy path at top level
```

### No Fixed Line Length

Go has no official line-length limit. When a line is too long, refactor — extract a variable, break up an expression — rather than just wrapping at an arbitrary column. Do not split function signatures or call expressions in ways that create misleading indentation.

### Nil Slices

Prefer nil slices over empty slices as the zero state. Test emptiness with `len(s) == 0`, not `s == nil`.

```go
// Prefer
var items []string

// Avoid unless an empty (non-nil) slice is semantically required
items := []string{}
```

### `:=` vs `var`

- Use `:=` when the variable is initialised to a non-zero value.
- Use `var x T` (or `var x = …`) when the zero value will be used directly, or when the declaration scope is large enough that the type annotation aids readability.

### `%q` for Strings in Diagnostics

Use `%q` when printing strings in error messages or log output. It quotes and escapes the value, making whitespace and invisible characters visible.

```go
return fmt.Errorf("unknown field %q in config", name)
```

---

## Imports

Group imports in this order, separated by blank lines:

1. Standard library
2. Third-party / project packages
3. Protocol buffer imports
4. Side-effect imports (`import _ "pkg"`)

Do not use dot imports (`import . "pkg"`). Avoid renaming imports except to resolve collisions or to shorten an uninformative generated name (proto packages: `import foopb "path/to/foo_go_proto"`).

Side-effect imports belong only in `main` packages or test files; never in libraries.

---

## Documentation Comments

Every exported symbol must have a doc comment. The comment must be a full sentence starting with the symbol's name.

```go
// Bad
// Represents an HTTP request.
type Request struct { … }

// Good
// Request represents an HTTP request.
type Request struct { … }
```

The package comment sits directly above the `package` declaration in exactly one file per package, with no blank line between comment and declaration.

Comments explain **why**, not what — well-named identifiers already say what.

---

## Functions and Options

Drop redundant words from function names — words already visible from the package, type, or parameter list add noise:

```go
// Bad
package yamlconfig
func ParseYAMLConfig(input string) (*Config, error)

// Good
func Parse(input string) (*Config, error)
```

### Option Patterns

**Option struct** — prefer when callers need several configuration fields:

```go
type Options struct {
    Timeout  time.Duration
    Retries  int
    BaseURL  string
}

func Connect(ctx context.Context, opts Options) (*Client, error) { … }
```

**Functional options** — prefer when most callers need zero options and advanced callers need a few:

```go
type Option func(*options)

func WithTimeout(d time.Duration) Option {
    return func(o *options) { o.timeout = d }
}
```

Options should accept parameters (`FailFast(enable bool)`), not rely on presence alone.

---

## Tests

### Useful Failures

A failing test must tell you what went wrong without running a debugger. Include the function under test, the inputs, the actual output, and the expected output.

```
YourFunc(%v) = %v, want %v
```

Use `cmp.Diff` for complex types:

```go
if diff := cmp.Diff(want, got); diff != "" {
    t.Errorf("Foo() mismatch (-want +got):\n%s", diff)
}
```

### `t.Fatal` vs `t.Error`

- `t.Fatal` / `t.Fatalf` — setup failures where proceeding is meaningless; call `t.Helper()` in helper functions so the failure is attributed to the call site.
- `t.Error` / `t.Errorf` — individual table-row failures; allows the remaining rows to run.

Never call `t.Fatal` from a spawned goroutine; use `t.Error` and return.

### Formatting

Always use field names in table-driven test struct literals:

```go
{name: "empty input", input: "", want: 0},
```
