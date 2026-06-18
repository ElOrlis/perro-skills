# Concurrency and Memory in Go

A reference for the parts of Go that are subtle: the memory model, the
synchronization edges the spec actually guarantees, the in-memory layout of
values, and the representation of interfaces. Sources: the official Go Memory
Model (`go.dev/ref/mem`, current text, last revised for Go 1.19+) and Russ
Cox's 2009 essays *Go Data Structures* and *Go Data Structures: Interfaces*.

> **A note on Russ Cox's 2009 essays.** Those essays describe a 32-bit
> reference machine and document an optimization where a word-sized value
> could be stored *directly* in an interface's data word, avoiding heap
> allocation. **That direct-storage optimization was removed in Go 1.4.**
> Modern Go always stores a pointer in the interface's data word; small
> values get copied to the heap on assignment. Treat the 32-bit word size
> and the direct-storage details below as **historical illustration**, not
> current fact. The current semantics are given alongside.

---

## 1. The Go Memory Model

### 1.1 The rule that matters most

From the spec:

> If you must read the rest of this document to understand the behavior of
> your program, you are being too clever. Don't be clever.

The intended programming model is: **share memory by communicating, not by
sharing**. Serialize access to mutable shared data with channels or with the
`sync` / `sync/atomic` primitives. Everything below exists so the few people
writing those primitives, or debugging a confirmed race, have a precise model
to reason against.

### 1.2 Happens-before, sequenced-before, synchronized-before

The model is a **partial order** over memory operations. A read `r` is
allowed to observe a write `w` to the same location only if `w` happens-
before `r` *and* no other write to that location happens-before `r` and after
`w`. If there are multiple writes that could legally be observed, the read
may return the value of any of them — happens-before is partial, not total.

The Go 1.19+ reformalization defines happens-before as the **transitive
closure** of two simpler relations:

- **sequenced-before** — the intra-goroutine order derived from Go's control
  flow and expression-evaluation rules. Within one goroutine, the program
  text gives you the order.
- **synchronized-before** — the inter-goroutine order derived from
  *synchronizing operations* (channel ops, mutex ops, atomics, `sync.Once`,
  package init, the `go` statement). If a synchronizing read-like operation
  `r` observes a synchronizing write-like operation `w`, then `w` is
  synchronized-before `r`.

`happens-before := transitive-closure(sequenced-before ∪ synchronized-before)`.

The older happens-before-only formulation is still valid; it is just less
modular. Any program correct under the old rules remains correct under the
new ones.

### 1.3 Data races are undefined behavior

A **data race** is two memory accesses to the same location, at least one of
which is a write, where neither is a synchronizing operation and neither
happens-before the other.

Go does not define what a program with a data race does. The spec provides
two narrow backstops, and they are not a license to race:

- A read of a memory location no larger than a machine word must observe a
  value that some real write actually stored there. There are no
  out-of-thin-air values.
- For locations larger than a word (slice headers, string headers, interface
  values, maps, function values, channels, `int64` on 32-bit platforms), the
  implementation may decompose the access into word-sized operations in
  unspecified order. A racy read of a multi-word value can therefore observe
  a **torn** value — pointer from one write, length from another — and the
  program can then corrupt memory or crash.

Anything else a racing program does is permitted, including: the race
detector terminating the program; the compiler hoisting, reordering, or
duplicating the racy access; a loop never terminating; a value appearing to
change without any write executing.

### 1.4 DRF-SC: the contract for correct programs

> In the absence of data races, Go programs behave as if all the goroutines
> were multiplexed onto a single processor.

This is **DRF-SC** (data-race-free implies sequential consistency). A
race-free Go program has exactly the outcomes you would get by interleaving
its goroutines' statements onto one CPU. Go shares this contract with C11,
C++11, Java 5+, Rust, and Swift: relaxed under the hood, sequentially
consistent for programs that synchronize properly.

The practical consequence is the central design rule:

- Write code so it is data-race-free.
- Verify with `go test -race` / `go run -race` / `go build -race`.
- Then reason about the program as if goroutines interleaved on one CPU.

---

## 2. The synchronization edges, precisely

Each rule below is a `synchronized-before` edge; chained through
sequenced-before, these are the edges that establish happens-before across
goroutines.

### 2.1 Package initialization

If package `p` imports package `q`, the completion of `q`'s `init` functions
is synchronized-before the start of any of `p`'s. The completion of all
`init` functions is synchronized-before the start of `main.main`. Anything a
package-level variable was set to during init is therefore visible to
`main.main` and to every goroutine started from it.

### 2.2 The `go` statement

The `go` statement that starts a new goroutine is synchronized-before the
start of that goroutine's execution. Writes the parent goroutine performed
before `go f()` are visible to `f`.

### 2.3 Goroutine exit

**Goroutine exit is not synchronized-before any event in the program.**
There is no implicit join. Writes a goroutine performs are not guaranteed
visible to anyone merely because the goroutine has ended. If you need its
results, signal completion through a channel, a `sync.WaitGroup`, a mutex
release, or an atomic store — and have the consumer read through the
matching synchronizing operation.

### 2.4 Channels

The channel rules are the heart of Go's synchronization story.

- **Send → receive.** A send on a channel is synchronized-before the
  completion of the corresponding receive.
- **Unbuffered receive → send.** On an *unbuffered* channel, the receive is
  synchronized-before the completion of the corresponding send. (Symmetric
  to the send-before-receive rule above. The pair gives unbuffered channels
  their rendezvous semantics: both sides see each other's prior writes.)
- **Close → zero-value receive.** Closing a channel is synchronized-before a
  receive that returns the zero value because the channel is closed. A
  goroutine waiting on `<-done` after `close(done)` therefore sees every
  write the closer made before the `close`.
- **Buffered channel as bounded semaphore.** For a channel of capacity `C`,
  the `k`th receive is synchronized-before the completion of the `(k+C)`th
  send. With `C = 1` this gives mutex-like ownership transfer. With larger
  `C`, the buffered channel is a counting semaphore — a classic pattern for
  limiting concurrency:

  ```go
  var limit = make(chan struct{}, 3)
  for _, w := range work {
      go func(w func()) {
          limit <- struct{}{} // acquire
          w()
          <-limit             // release
      }(w)
  }
  ```

### 2.5 `sync.Mutex` and `sync.RWMutex`

For any `sync.Mutex` or `sync.RWMutex` value `l` and integers `n < m`: the
`n`th call to `l.Unlock()` is synchronized-before the `m`th call to
`l.Lock()` that returns. In plain terms: whatever you wrote while holding
the lock is visible to the next holder.

For `RWMutex`: the `n`th `Unlock()` is synchronized-before any later
`RLock()` return whose matching `RUnlock()` is synchronized-before the
`(n+1)`th `Lock()` return. Successful `TryLock` / `TryRLock` behave like
`Lock` / `RLock`; *unsuccessful* tries establish no synchronization at all —
treat a failed `TryLock` as if you never touched the mutex.

### 2.6 `sync.Once`

The completion of the single call to `f` inside `once.Do(f)` is
synchronized-before the return of *every* call to `once.Do(f)`. This is the
correct primitive for one-shot initialization; do not roll your own with a
`done` flag (see §5.2).

### 2.7 `sync/atomic`

If atomic operation `B` observes the effect of atomic operation `A`, then
`A` is synchronized-before `B`. Furthermore, all atomic operations in a
program behave as though they executed in some single, sequentially
consistent total order. Go's atomics are SC atomics — equivalent to C++
`memory_order_seq_cst`, Java `volatile`, and the strongest level of C11/Rust
atomics. There are no acquire/release/relaxed variants in `sync/atomic`.

### 2.8 Finalizers

`runtime.SetFinalizer(x, f)` is synchronized-before the call to `f(x)`. The
finalizer call itself is in a fresh goroutine and is not ordered against
anything else by the model — use channels to publish results.

---

## 3. Memory layout

This section uses "word" in the machine sense — the natural pointer-sized
unit on the target architecture. On modern 64-bit hardware a word is 8
bytes. The Russ Cox 2009 essay assumed a 32-bit word, but the *shape* of
every value below (one word, two words, three words, …) is unchanged on
64-bit; only the absolute sizes scale.

### 3.1 Scalars

`int`, `int32`, `int64`, `uintptr`, `float32`, `float64`, and every pointer
type occupy one word in the layout sense, with the caveat that `int64` and
`float64` are 8 bytes regardless of platform — so on a 32-bit target an
`int64` field is two words. `int` itself is platform-sized: 4 bytes on a
32-bit target, 8 bytes on a 64-bit target. `bool` and `byte` are smaller
than a word but participate in struct alignment.

### 3.2 Structs

Fields of a struct are laid out in declaration order, with padding inserted
for alignment. A struct does not carry a header. So:

```go
type Point struct{ X, Y int }
```

is two adjacent `int` words inline. `*Point` is one word — a pointer to such
a pair, separately allocated. **The programmer decides what is and is not a
pointer** by choosing inline embedding versus a pointer field. This is a
deliberate departure from languages that make that decision for you, and it
is the foundation of Go's control over allocation and cache layout.

### 3.3 Strings

A `string` value is **two words**: a pointer to the underlying bytes and a
length. The bytes are immutable. Slicing a string (`s[i:j]`) returns a new
two-word header that shares the underlying bytes — no copying, no
allocation.

### 3.4 Slices

A slice value is **three words**: a pointer to the first element, a length,
and a capacity. The pointer references a separately allocated backing array.
Slicing a slice (`s[i:j]` or `s[i:j:k]`) produces a new three-word header
that aliases the same backing array; no element data is copied. `append` may
or may not allocate a new backing array, depending on capacity.

### 3.5 Maps, channels, function values, interfaces

`map`, `chan`, and function values are *reference types* whose value is a
single-word pointer to an opaque runtime structure. Interfaces are
two-word values; see §4.

### 3.6 `new` vs `make`

- `new(T)` allocates zeroed storage for a `T` and returns a `*T`. It is
  appropriate for any type.
- `make(T, …)` is defined only for `slice`, `map`, and `chan`. It returns a
  `T` (not a `*T`), fully constructed and ready to use: a slice header
  pointing at a backing array of the requested length/capacity; a map with
  its hash table allocated; a channel with its buffer allocated. A
  `new(map[K]V)` gives you a `*map[K]V` pointing at a nil map header, which
  is almost always not what you want.

### 3.7 Multiword values and races

Because string, slice, interface, and (effectively) map and channel headers
are larger than a word, a racing read of one of these can observe a torn
header — for example, a slice pointer from one assignment paired with a
length from another. The resulting slice will index outside the new backing
array. This is the mechanism by which "just a race on a slice" turns into
out-of-bounds memory corruption rather than a benign stale read.

---

## 4. Interfaces

### 4.1 Representation

An interface value is **two words**:

- a pointer to an **itable** (or, for the empty interface, a pointer to a
  `*_type`),
- a **data pointer**.

The runtime distinguishes two flavors internally:

- `iface` — for interfaces with at least one method. First word is an
  `*itab` (interface type, concrete type, and a flat array of function
  pointers, one per method of the interface, in interface-declaration
  order).
- `eface` — for the empty interface `interface{}` / `any`. First word is
  just a `*_type` describing the concrete type; there are no methods to
  dispatch, so no itable is needed.

In both cases the second word is a pointer to the concrete value. The
two-words shape applies uniformly; the difference is only what the first
word points at.

### 4.2 The itable

The itable is keyed on `(interface type, concrete type)`. It contains:

- a pointer to the interface type descriptor,
- a pointer to the concrete type descriptor (with which you can recover the
  full concrete method set, hash code, name, etc.),
- a flat array of function pointers — exactly the methods the *interface*
  requires, resolved against the *concrete* type's method set, in the order
  the interface declares them.

Methods the concrete type has that the interface does not require are not
referenced from the itable; they live in the concrete type's full method
table.

Itables are computed by walking the concrete type's sorted method table and
the interface's sorted method list in parallel — O(n_iface + n_concrete) —
and then cached in a hash table keyed by `(interface, concrete)`. Many
itables can be resolved by the linker; the rest are computed by the runtime
on first assignment and reused thereafter.

### 4.3 Method dispatch

A call `v.M(args)` on an interface `v` of static type `I`, where `M` is the
`k`th method of `I`, compiles to the equivalent of:

```c
v.tab->fun[k](v.data, args...)
```

That is: one indirect load of the function pointer from the itable, and one
indirect call passing the data pointer as the receiver. Two fetches and an
indirect call — no method-name lookup at the call site, no runtime string
comparison, no walking of method lists.

### 4.4 Type assertions and type switches

`x, ok := v.(T)` reads `v.tab->_type` (for `iface`) or `v._type` (for
`eface`) and compares it against `T`'s type descriptor. For an assertion to
an interface type `J`, the runtime looks up or computes the
`(J, concrete-of-v)` itable; success populates `x` with that itable plus the
data pointer.

### 4.5 Cost model

Interface dispatch in Go is a *constant-cost* operation at the call site:
two loads and an indirect call. The cost of figuring out *which* function to
call is paid once, at **assignment time** — when a concrete value is
converted to the interface — and the result is cached in the itable. This
is why a tight loop that repeatedly calls the same method through the same
interface variable does not pay any per-call lookup cost.

What interface dispatch *does* cost relative to a direct call:

- The indirect call is opaque to the inliner. A direct call to a known
  concrete method can be inlined; a call through an interface generally
  cannot.
- Assigning a concrete value to an interface causes the concrete value to
  be addressed in memory so the data pointer can refer to it. For small
  values, this means a small heap allocation. (This is exactly the cost
  that the 2009 essays' direct-storage optimization tried to avoid; that
  optimization is gone since Go 1.4.)
- The branch predictor cannot specialize an indirect call as well as a
  direct one when the concrete type at a call site varies.

For the overwhelming majority of code these costs are irrelevant; for
hot-path numerics or tight data-structure inner loops they are real.

---

## 5. Decision rules

These are the rules to actually follow. The rest of this document explains
why.

### 5.1 Share memory by communicating

When two goroutines need to coordinate on a value, prefer transferring
*ownership* of that value over a channel. The send-before-receive edge does
the synchronization for you: any writes the sender made before the send are
visible to the receiver after the receive.

### 5.2 Always run the race detector

`go test -race`, `go run -race`, and `go build -race` instrument the binary
to detect data races at runtime. Run race-instrumented binaries in CI and
in any meaningful integration testing. A data race is **always** a bug —
not a tolerable one, not a "well it works in practice" one. The behavior is
undefined; today's working build is tomorrow's torn slice header.

### 5.3 Never invent your own synchronization

Use channels, `sync`, or `sync/atomic`. Do not implement Dekker's algorithm
on plain variables. Do not "use a `bool` as a flag, it's just one word."
The compiler and the hardware are allowed to reorder, fuse, and reload
non-synchronizing accesses as long as a sequential observer of *that
goroutine alone* could not tell. A racy flag is not a flag.

Concretely, the canonical broken patterns are:

```go
// BROKEN: double-checked locking on a plain bool.
var a string
var done bool
var once sync.Once
func setup()  { a = "hello"; done = true }
func doprint() {
    if !done { once.Do(setup) }
    print(a) // may print "" or crash on a torn string header
}
```

Observing `done == true` does not, by itself, establish any happens-before
edge with the assignment to `a`. Use `sync.Once` and read `a` *only*
through `Do`.

### 5.4 Never busy-wait on an unsynchronized variable

```go
// BROKEN.
var done bool
go func() { a = "hello"; done = true }()
for !done { }    // may loop forever; the compiler may hoist the load
print(a)         // and even if it exits, a may be unobservable
```

`for !done {}` is permitted to compile to a load-once-and-spin-on-a-register
loop. Even if it does observe the store, there is no synchronizing edge to
publish `a`. Replace with a channel receive, a `sync.WaitGroup.Wait`, or a
`sync/atomic.Load` paired with `Store`.

### 5.5 Do not rely on goroutine exit order

Goroutine termination is not a synchronizing event (§2.3). The only thing
that orders one goroutine's writes against another goroutine's reads is an
explicit synchronizing operation between them.

### 5.6 Publish before the synchronizing op; read after it

The mental model that always works:

1. Goroutine A performs the writes you want to publish.
2. Goroutine A executes a synchronizing operation: send on a channel,
   `Unlock`, `Store` on an atomic, `close`, `Done` on a WaitGroup.
3. Goroutine B executes the matching synchronizing operation: receive,
   `Lock`, `Load`, zero-value receive on a closed channel, `Wait`.
4. Goroutine B then reads the published data.

Writes done *after* step 2 in A have no ordering against reads done *before*
step 3 in B. Order the code so the publication is on the inside of the
synchronizing op, and the read is on the inside of the matching op.

### 5.7 Treat multiword values as fragile under races

`string`, `[]T`, `map[K]V`, `chan T`, `interface{}`, and function values are
all larger than a word in their value representation or carry pointers to
mutable runtime structures (maps especially). A race on any of them is not
"a stale value" — it is "potentially a torn header that the next operation
will dereference into arbitrary memory." There is no benign race on these
types. Synchronize.

---

## 6. Further reading

- *The Go Memory Model* — `go.dev/ref/mem`. The normative source. Re-read
  when in doubt; it is short.
- Russ Cox, *Go Data Structures* (2009) — `research.swtch.com/godata`. The
  layout intuitions still hold; absolute sizes are 32-bit-era.
- Russ Cox, *Go Data Structures: Interfaces* (2009) —
  `research.swtch.com/interfaces`. Itable mechanics still hold; the
  direct-storage-in-data-word optimization described there was removed in
  Go 1.4 and does not apply to current Go.
- `runtime/iface.go`, `runtime/type.go` in the Go source tree, for the
  current `iface` / `eface` / `itab` / `_type` definitions.
