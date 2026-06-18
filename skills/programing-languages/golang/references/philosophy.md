# Go Design Philosophy

Three essays from Go's authors that shape how to reason about the language and make judgment calls in its spirit.

---

## Cox — "Dogma" (2014)

**Argument:** Language design is engineering. Every decision is a tradeoff evaluated at a moment in time, weighed against real alternatives that had genuine merit. Dogma is what happens when users forget this and start treating those decisions as commandments.

The tell of dogma is the non-argument: *"that's just not how it's done here."* It dismisses the other side without engaging it. Cox asks designers and community members alike to instead explain both sides of a decision — because the people who made it did exactly that.

> "Remember that none of the decisions in Go are infallible; they're just our best attempts at the time we made them."

Corollary: when you disagree with a Go design choice, engage the tradeoff. Saying "other languages do X" is not an argument unless you've weighed the costs that led Go to reject X.

---

## Pike — "Esmerelda's Imagination" (2011)

**Argument:** The essay opens with an actress, Esmerelda, who says "I can't imagine being anything except an actress." The reply: "You can't be much of an actress then, can you?" The constraint isn't commitment — it's a failure of imagination.

The analog: a programmer who says "I can't imagine programming without generics" (or closures, or exceptions, or any feature Go omits) is revealing the limits of their own imagination, not a defect of the language. The complaint tells you more about the complainer than the complained-about.

A deeper mistake is treating Go as a substrate for translating another language into it. Someone with ten years of Java and ten minutes of Go produces Java-in-Go, then complains the language is deficient. But Go is not designed to be idiomatic Java — it demands reorientation to its own idioms. The vituperation that pours out of such comparisons amounts to "a few extra keystrokes" dressed up as principle.

Authority to criticize comes from "experience and insight, which require practice and imagination. And maybe some programming."

**Disposition:** Learn Go on its own terms before evaluating it. Spend the effort solving the problem rather than writing the complaint.

---

## Pike — "Regular Expressions in Lexing and Parsing" (2011)

**Argument:** Regexps are the wrong tool for lexing or parsing grammars that are known at compile time. For static, well-defined structure, use a hand-written lexer / state machine or a real parser.

Reasons:

- **Performance.** Regexp engines carry hidden overhead; capturing submatches makes it worse. A simple hand-written loop is faster and involves less underlying machinery.
- **Heavyweight.** "Using one to parse identifiers is like using a Mack truck to go to the store for milk." The tool is not proportionate to the task.
- **Adaptability.** When requirements shift — say, Unicode identifiers — a hand-written loop absorbs the change cleanly. A regexp approach typically breaks down.
- **Endemic misuse.** During code reviews, Pike fixes a far higher fraction of the regular expressions in the code than regular statements, because most programmers "simply don't know what they are or how to use them correctly."

Regexps are the **right** tool when the pattern is discovered dynamically — text editors, search tools, grep, user-supplied queries. The distinction is compile-time-known structure vs. runtime-unknown pattern.

> "Your code will be faster, cleaner, and much easier to understand and to maintain" using standard lexing and parsing techniques.

---

## Dispositions

These three essays converge on a set of judgment rules:

| Situation | Disposition |
|-----------|-------------|
| A style rule feels absolute | Treat it as a guideline with tradeoffs, not a commandment |
| Justification is "that's how it's done here" | Reject it — engage the actual tradeoff |
| You disagree with a Go design choice | State both sides; hold your position as a fallible best-attempt |
| Evaluating Go against another language | Learn Go's idioms first; comparison without practice produces noise |
| Tempted to use `regexp` to parse structured input | Write a state machine or use a real parser instead |
| Pattern is user-supplied or discovered at runtime | `regexp` is appropriate here |
| Simple is available, clever is possible | Prefer clear, explicit, simple |
