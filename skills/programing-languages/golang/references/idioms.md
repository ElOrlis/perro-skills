# Go Idioms

A distilled reference for writing Go that reads like Go. Synthesized from
*Effective Go*, the *Go Proverbs*, and Rob Pike's *Less is exponentially more*.

---

## 1. Formatting

`gofmt` is canonical and non-negotiable. Run it; argue about nothing.

- Indent with **tabs**, align with spaces.
- Braces go on the **same line** as the statement — the language's automatic
  semicolon insertion depends on it. Writing `{` on its own line breaks the
  parser.
- One statement per line; no trailing semicolons in source.
- **Doc comments precede the declaration**, with no blank line between, and
  begin with the name of the thing being documented:

  ```go
  // Compile parses a regular expression and returns, if successful,
  // a Regexp that can be used to match against text.
  func Compile(expr string) (*Regexp, error) { ... }
  ```

> *Gofmt's style is no one's favorite, yet gofmt is everyone's favorite.*

---

## 2. Naming

**Short, lowercase, single-word package names.** `bufio`, `ring`, `http`.
Avoid `util`, `common`, `helpers`. The package name is part of every
identifier it exports, so design against **stutter**:

```go
bufio.Reader   // not bufio.BufReader
ring.New       // not ring.NewRing
```

- **Getters** drop the `Get`: `owner.Name()`, not `owner.GetName()`. The
  setter, if any, is `SetName`.
- **One-method interfaces** are named for the method plus `-er`: `Reader`,
  `Writer`, `Formatter`, `Stringer`, `Closer`.
- **MixedCaps**, not `snake_case` or `SCREAMING_CASE`. Capitalization of
  the first letter is the export mechanism — there is no `public`/`private`
  keyword.
- Local names are short (`i`, `r`, `buf`); exported names are descriptive.
  Scope and length scale together.

---

## 3. Control structures

No parentheses around conditions. Bodies always require braces.

**`if` with an initializer** scopes the variable to the `if`/`else`:

```go
if err := f(); err != nil {
    return err
}
```

**Omit `else` after a terminating branch.** If the `if` body ends in
`return`/`break`/`continue`/`panic`, drop the `else`:

```go
if x == nil {
    return errBad
}
// continue with x
```

**`for` is the only loop.** Four shapes, one keyword:

```go
for i := 0; i < n; i++ { ... }   // C-style
for x < limit          { ... }   // while
for                    { ... }   // infinite
for i, v := range s    { ... }   // range
```

`range` over a string yields **runes**, decoding UTF-8 — not bytes:

```go
for i, r := range "héllo" { // r is rune, i is byte index
    ...
}
```

**`switch`** has no automatic fallthrough. The expression is optional
(`switch { ... }` works as a chained `if/else`), and cases can be
comma-separated:

```go
switch {
case x < 0:
    return -1
case x == 0:
    return 0
default:
    return 1
}

switch c {
case ' ', '\t', '\n':
    return true
}
```

**Type switch** binds the dynamic type:

```go
switch v := x.(type) {
case nil:
    // x is untyped nil
case int:
    return v * 2
case fmt.Stringer:
    return len(v.String())
default:
    return 0
}
```

---

## 4. Functions

**Multiple return values** are idiomatic — Go uses them instead of out
params or exceptions. The conventional last return is `error`:

```go
f, err := os.Open(name)
if err != nil {
    return err
}
defer f.Close()
```

**Named result parameters** document intent and enable a bare `return`:

```go
func split(sum int) (x, y int) {
    x = sum * 4 / 9
    y = sum - x
    return
}
```

Use them when the names clarify meaning at the call site; don't add them
just to use bare returns.

**`defer`** runs at function exit in **LIFO** order; arguments are
**evaluated at the `defer` statement**, not at execution. Pair every
acquire with a deferred release at the line of acquisition:

```go
mu.Lock()
defer mu.Unlock()

f, err := os.Open(name)
if err != nil { return err }
defer f.Close()
```

---

## 5. Data

### `new` vs `make`

- `new(T)` allocates **zeroed** storage and returns `*T`. Works for any type.
- `make(T, args)` initializes the runtime structure of **slices, maps, and
  channels**, returning `T` (not `*T`).

```go
p := new(bytes.Buffer)        // *bytes.Buffer, ready to use (zero value)
s := make([]int, 0, 16)       // slice with len 0, cap 16
m := make(map[string]int)
c := make(chan int, 4)
```

Make the **zero value useful**: `sync.Mutex{}`, `bytes.Buffer{}`, and a
`nil` slice all work without explicit initialization.

### Composite literals

```go
p := Point{X: 1, Y: 2}
ss := []string{"a", "b"}
m := map[string]int{"one": 1, "two": 2}
```

### Arrays vs slices

- **Arrays are values.** `[N]T` includes its length in the type; assignment
  and parameter passing copy the whole array.
- **Slices are references** into a backing array, carrying `len` and `cap`.

`append` may reallocate — **always reassign the result**:

```go
s = append(s, x)         // correct
append(s, x)             // bug: result discarded
s = append(s, more...)   // splat
copy(dst, src)           // element-wise copy
```

### Maps

Zero value of a map is `nil`; you must `make` before assigning. Reading a
missing key returns the value's zero. Use the **comma-ok** form to
distinguish "missing" from "zero":

```go
v, ok := m[k]
if !ok { ... }
delete(m, k)
```

Sets are spelled `map[T]bool` (or `map[T]struct{}` when you care about
size).

### Printing

`fmt` verbs: `%v` (default), `%+v` (with field names), `%#v` (Go syntax),
`%T` (type), `%d/%x/%s/%q`. Implement `String() string` (the `Stringer`
interface) to control how a type prints — never call `String` from `String`,
or you'll recurse.

### Constants and `iota`

`iota` is the index inside a `const` group, starting at 0. Use it for
enums and bit flags:

```go
type Weekday int
const (
    Sunday Weekday = iota
    Monday
    Tuesday
    // ...
)

const (
    FlagRead  = 1 << iota // 1
    FlagWrite             // 2
    FlagExec              // 4
)
```

### `init`

Each file may declare `func init()`; they run after variable
initialization, before `main`. Use sparingly — for registration and
invariant checks, not for work.

---

## 6. Methods: pointer vs value receivers

```go
func (b *Buffer) Write(p []byte) (int, error) { ... }   // pointer receiver
func (p Point)   Distance(q Point) float64    { ... }   // value receiver
```

Rules of thumb:

- Use a **pointer receiver** if the method mutates the receiver, the type
  contains a `sync.Mutex` or other non-copyable field, or the type is large.
- Use a **value receiver** for small, immutable, value-like types (`time.Time`,
  `Point`).
- **Be consistent**: don't mix receiver kinds on the same type without
  reason.

### Method sets and interfaces

The method set of `T` contains only value-receiver methods. The method set
of `*T` contains both. Consequence: only a `*T` satisfies an interface that
includes a pointer-receiver method.

```go
type Stringer interface{ String() string }

func (b *Buffer) String() string { ... }

var s Stringer = &Buffer{} // ok
var s Stringer =  Buffer{} // compile error: Buffer lacks String()
```

---

## 7. Interfaces

Satisfaction is **implicit and structural**. A type implements an interface
by having the methods — no `implements` keyword, no declaration of intent.
This is what enables retrofitting interfaces around code you don't own.

Keep interfaces **small** — a behavioral contract, not a type taxonomy.
`io.Reader` and `io.Writer` are one method each, and they compose into
everything.

> *The bigger the interface, the weaker the abstraction.*

**Accept interfaces, return concrete types.** Callers should depend on the
narrowest behavior they actually need.

### Function types as interfaces

A named function type can carry a method, letting a plain function satisfy
an interface:

```go
type Handler interface {
    ServeHTTP(ResponseWriter, *Request)
}

type HandlerFunc func(ResponseWriter, *Request)

func (f HandlerFunc) ServeHTTP(w ResponseWriter, r *Request) {
    f(w, r)
}
```

### The blank identifier `_`

Three idiomatic uses:

1. **Discard** an unwanted value:
   ```go
   _, err := io.Copy(dst, src)
   for _, v := range s { ... }
   ```
2. **Side-effect imports** — run a package's `init` without referring to it:
   ```go
   import _ "image/png"           // register PNG decoder
   import _ "net/http/pprof"      // mount pprof handlers
   ```
3. **Compile-time interface check** — assert that `*T` satisfies `Iface`
   without keeping a runtime value:
   ```go
   var _ http.Handler = (*myHandler)(nil)
   ```

### Embedding and method promotion

Go has no inheritance. It has **embedding**: include a type as an
anonymous field, and its methods are **promoted** onto the outer type.

```go
type ReadWriter struct {
    *bufio.Reader  // embedded
    *bufio.Writer  // embedded
}
// rw.Read, rw.Write, rw.Flush all work without forwarding code
```

Interfaces embed too:

```go
type ReadWriter interface {
    Reader
    Writer
}
```

Embedding is **composition**, not subclassing — there is no "is-a"
relationship, only a set of available methods. Name collisions during
promotion become ambiguous and must be resolved explicitly.

---

## 8. Concurrency

Three primitives: **goroutines**, **channels**, **`select`**.

```go
go server(ch)             // launch a goroutine
ch <- v                   // send
v  := <-ch                // receive
v, ok := <-ch             // ok==false when closed and drained
close(ch)
```

- **Unbuffered** channels synchronize: sender and receiver rendezvous.
- **Buffered** channels decouple up to N items and double as **semaphores**
  / worker pools:

  ```go
  sem := make(chan struct{}, maxConcurrent)
  for _, job := range jobs {
      sem <- struct{}{}
      go func(j Job) {
          defer func() { <-sem }()
          process(j)
      }(job)
  }
  ```

- **`select`** waits on multiple channel operations; `default` makes it
  non-blocking:

  ```go
  select {
  case v := <-in:
      handle(v)
  case out <- result:
  case <-time.After(timeout):
      return errTimeout
  default:
      // nothing ready
  }
  ```

The slogan:

> *Don't communicate by sharing memory; share memory by communicating.*

Mutexes still exist (`sync.Mutex`, `sync.RWMutex`) and are right when you
have a small piece of state to protect. Channels are right when you have
ownership to transfer.

> *Concurrency is not parallelism.* Concurrency is a way to **structure** a
program as independent processes; parallelism is **executing** computations
simultaneously. Concurrent code may run on one core; parallel code needs
many. Go gives you the structuring tool.

### Errors

Errors are values that implement:

```go
type error interface { Error() string }
```

Define custom error types when callers need to **inspect** them:

```go
type PathError struct {
    Op   string
    Path string
    Err  error
}
func (e *PathError) Error() string { return e.Op + " " + e.Path + ": " + e.Err.Error() }
func (e *PathError) Unwrap() error { return e.Err }
```

Inspect with `errors.Is` / `errors.As`. **Handle**, don't just propagate:
add context (`fmt.Errorf("read %s: %w", name, err)`), pick a fallback,
retry, or fail loudly — but make a decision.

> *Errors are values.* &nbsp; *Don't just check errors, handle them gracefully.*

### Panic and recover

`panic` is for **unrecoverable** programmer errors (impossible states,
invariant violations during initialization). `recover` — only valid inside
a deferred function — turns a panic back into an error at package
boundaries. Never use it as exception handling.

> *Don't panic.*

---

## 9. The Go Proverbs

The 19 proverbs, verbatim:

1. Don't communicate by sharing memory, share memory by communicating.
2. Concurrency is not parallelism.
3. Channels orchestrate; mutexes serialize.
4. The bigger the interface, the weaker the abstraction.
5. Make the zero value useful.
6. interface{} says nothing.
7. Gofmt's style is no one's favorite, yet gofmt is everyone's favorite.
8. A little copying is better than a little dependency.
9. Syscall must always be guarded with build tags.
10. Cgo must always be guarded with build tags.
11. Cgo is not Go.
12. With the unsafe package there are no guarantees.
13. Clear is better than clever.
14. Reflection is never clear.
15. Errors are values.
16. Don't just check errors, handle them gracefully.
17. Design the architecture, name the components, document the details.
18. Documentation is for users.
19. Don't panic.

---

## 10. Less is exponentially more (Pike)

Rob Pike's thesis, distilled:

- Go's expressive power comes from what it **leaves out**, not what it adds.
  No class hierarchies. No exceptions. No generic type taxonomy of
  `Animal → Mammal → Dog`. No constructor overloading. No `this`.
- **Composition over inheritance.** Interfaces describe **capability**
  (what a value can do), embedding **assembles** behavior from parts.
  Neither encodes lineage. A `*bytes.Buffer` is an `io.Writer` because it
  has `Write`, not because it descends from anything.
- **Concurrency is not parallelism.** Goroutines and channels exist to let
  you express the structure of a program as concurrent, communicating
  pieces — independent of how many cores will run them.
- The friction with experienced C++ and Java programmers is philosophical,
  not technical. Those languages are built around giving the programmer
  **exquisite control** over everything; Go is built around **minimizing
  programmer effort** to produce clear, correct, working software. The
  trade is intentional. Programmers who want every knob find Go missing
  features; programmers who want to ship find those knobs were the problem.
- Therefore: small interfaces, plain data, explicit error returns,
  channels for coordination, no inheritance, gofmt for everything else.

> *Less can be more. The better you understand, the pithier you can be.*

---

## 11. Decision rules (cheat sheet)

| Situation                                | Do this                                        |
|------------------------------------------|------------------------------------------------|
| Need a `*T` zero value                   | `new(T)`                                       |
| Need a slice/map/channel                 | `make(...)`                                    |
| Want to test "missing vs zero" in a map  | `v, ok := m[k]`                                |
| Calling `append`                         | Reassign: `s = append(s, x)`                   |
| Method mutates receiver / type is large  | Pointer receiver                               |
| Type is small and value-like             | Value receiver                                 |
| Mixed receivers on one type              | Don't, unless you can defend it                |
| Designing an interface                   | Make it smaller                                |
| Coordinating goroutines                  | Channel; mutex only to guard a small struct    |
| Encountered `interface{}` / `any`        | Reach for a real type first                    |
| Tempted by reflection                    | Try code generation or an interface first      |
| Found a bug in someone else's design     | A little copying beats a little dependency     |
| About to write a comment                 | First check the name; rename instead if you can|
| About to `panic` in library code         | Return an error instead                        |
| Formatting argument                      | There isn't one — run `gofmt`                  |
