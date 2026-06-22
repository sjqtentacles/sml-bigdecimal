# sml-bigdecimal

[![CI](https://github.com/sjqtentacles/sml-bigdecimal/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-bigdecimal/actions/workflows/ci.yml)

Arbitrary-precision decimal arithmetic for Standard ML.

`sml-bigdecimal` provides a `Decimal` structure: a Java-`BigDecimal`-style
decimal type built on the Basis Library's arbitrary-precision integers
(`IntInf`). A value is a coefficient times a power of ten, so arithmetic is
exact and overflow-free, the scale (number of decimal places) is preserved,
and any digit-discarding operation takes an explicit rounding mode.

The Standard ML Basis Library has no decimal type, so this fills a real gap.
The library is **pure Standard ML (Basis-only)** and portable; it is tested on
**MLton** and **Poly/ML**.

## Why

`real` is binary floating-point: `0.1 + 0.2` is not `0.3`, and you cannot ask
for "exactly two decimal places, rounded half-even." That makes `real` wrong
for money and anything human-facing. `Decimal` is exact in base ten and keeps
its scale, so `0.1 + 0.2` is `0.3` and `2.50` stays `2.50`.

```sml
val price = valOf (Decimal.fromString "19.99")
val tax   = Decimal.setScale Decimal.HALF_EVEN 2
              (Decimal.* (price, valOf (Decimal.fromString "0.0825")))
val () = print (Decimal.toString tax ^ "\n")   (* "1.65" *)
```

## Model

A value represents `coeff * 10^(-scale)`:

| Value    | coeff | scale |
|----------|-------|-------|
| `3.14`   | `314` | `2`   |
| `100`    | `100` | `0`   |
| `-0.001` | `-1`  | `3`   |

The scale is meaningful and user-controlled (unlike a rational, the trailing
zeros in `2.50` are kept). Sign lives in the coefficient; scale is always `>= 0`.

- `+` and `-` promote to the larger of the two input scales (`2.5 + 1.00 = 3.50`).
- `*` adds the input scales (`1.5 * 2.0 = 3.00`).
- `div` and `setScale` take an explicit target scale and rounding mode, so
  precision is never discarded silently.

## Signature

```sml
signature DECIMAL =
sig
  type decimal
  type t = decimal

  datatype rounding = HALF_EVEN | HALF_UP | FLOOR | CEILING | TRUNCATE

  val zero : t
  val one  : t

  val fromInt    : int -> t
  val fromIntInf : IntInf.int -> t
  val fromString : string -> t option   (* "3.14", "-0.001", "100", "1e3", ".5", "2.5E-2" *)

  val scale    : t -> int
  val coeff    : t -> IntInf.int
  val setScale : rounding -> int -> t -> t       (* raises General.Domain if scale < 0 *)

  val ~   : t -> t
  val +   : t * t -> t                           (* result scale = max of input scales *)
  val -   : t * t -> t                           (* result scale = max of input scales *)
  val *   : t * t -> t                           (* result scale = sum of input scales *)
  val div : rounding -> int -> t * t -> t        (* explicit result scale; raises General.Div on zero *)

  val roundTo  : rounding -> int -> t -> t        (* round to n fractional digits *)
  val round    : rounding -> t -> t               (* round to an integer (scale 0) *)
  val floor    : t -> t                           (* to integer, toward negative infinity *)
  val ceil     : t -> t                           (* to integer, toward positive infinity *)
  val truncate : t -> t                           (* to integer, toward zero *)

  val pow  : t * int -> t                         (* integer power; exponent >= 0 *)
  val sqrt : int -> t -> t                        (* square root to n fractional digits (Newton) *)

  val compare : t * t -> order
  val equal   : t * t -> bool                    (* by value: 2.5 = 2.50 *)

  val toReal   : t -> real                       (* approximation *)
  val toString : t -> string                     (* "3.14", "-0.001", "100" *)
end
```

### Notes

- **Rounding modes.** `HALF_EVEN` (banker's rounding, the money default),
  `HALF_UP`, `FLOOR` (toward negative infinity), `CEILING` (toward positive
  infinity), and `TRUNCATE` (toward zero).
- **Equality is by value.** `2.5` and `2.50` are `equal` and `compare` `EQUAL`,
  even though their representations differ.
- **`toReal` is an approximation.** Decimals are exact, but `real` is binary
  floating-point, so `toReal` returns the nearest `real`, not an exact result.
- **Error handling.** `div` by zero raises `General.Div`; a negative target
  scale (in `div` or `setScale`) raises `General.Domain`. `fromString` returns
  `NONE` on malformed input.
- **`fromString` grammar.** Optional sign (`-`, `~`, or `+`), an integer part,
  an optional `.` with a fractional part (`.5` is allowed; `3.` is not), and an
  optional `e`/`E` exponent.

### Rounding, powers, and square roots

Beyond `setScale`, the library offers named rounding helpers, integer powers,
and a decimal square root. Everything is computed over the exact `IntInf`
coefficient — the square root uses Newton's method on the scaled integer, never
machine `real` — so results are deterministic and identical across compilers.

```sml
Decimal.round HALF_EVEN (d "2.5")        (* 2  (banker's rounding) *)
Decimal.round HALF_UP   (d "2.5")        (* 3 *)
Decimal.roundTo HALF_UP 2 (d "1.2345")   (* 1.23 *)

Decimal.floor    (d "2.9")               (* 2  *)
Decimal.ceil     (d "2.1")               (* 3  *)
Decimal.truncate (d "-2.9")              (* -2 *)

Decimal.pow  (d "1.1", 2)                (* 1.21 *)
Decimal.sqrt 10 (d "2")                  (* 1.4142135623 *)
```

- **`round` / `roundTo`.** `roundTo mode n` rounds to exactly `n` fractional
  digits (a named alias of `setScale`); `round mode` rounds to an integer
  (scale 0). Both reuse the existing `rounding` modes.
- **`floor` / `ceil` / `truncate`.** Convenience rounding to an integer toward
  negative infinity, positive infinity, and zero respectively.
- **`pow (x, e)`.** Integer power; `pow (x, 0) = one` and the result scale is
  `scale x * e`, so the value is exact. A negative exponent raises
  `General.Domain` (use `div` with an explicit scale for reciprocals).
- **`sqrt n x`.** Square root truncated to `n` fractional digits via Newton's
  method on the scaled coefficient, so `result^2 <= x`. A negative operand or
  negative `n` raises `General.Domain`.

## Installing with smlpkg

This library follows the conventions of the
[`smlpkg`](https://github.com/diku-dk/smlpkg) package manager. There is no
registry or account to sign up for -- packages are referenced directly by
their git URL. In your own project's directory:

```sh
smlpkg add github.com/sjqtentacles/sml-bigdecimal
smlpkg sync
```

This downloads the library into
`lib/github.com/sjqtentacles/sml-bigdecimal/`. Reference its `.mlb` from your
own `.mlb` with a relative path.

## Usage

### MLton

```
$(SML_LIB)/basis/basis.mlb
lib/github.com/sjqtentacles/sml-bigdecimal/decimal.mlb
your-code.sml
```

### Poly/ML

```sml
use "lib/github.com/sjqtentacles/sml-bigdecimal/decimal.sig";
use "lib/github.com/sjqtentacles/sml-bigdecimal/decimal.sml";
```

## Building and testing

The test suite is a dependency-free assertion runner (pure Standard ML) that
exits non-zero if any assertion fails.

```sh
make test        # build + run the suite under MLton
make test-poly   # run the suite under Poly/ML
make all-tests   # run under both
make clean
```

Built test-first (TDD): the signature and full suite were written first against
a stub, confirmed to compile and fail (red), then implemented to green.

## Related

For exact fractions with no rounding at all (e.g. `1/3` held exactly), see the
companion library [sml-rational](https://github.com/sjqtentacles/sml-rational).
`Rational` is for loss-free exact arithmetic; `Decimal` is for scale-controlled,
human-readable decimal values with explicit rounding.

## Layout

```
sml.pkg                 smlpkg manifest (package name + requires)
lib/github.com/sjqtentacles/sml-bigdecimal/
  decimal.sig           the DECIMAL signature (the contract)
  decimal.sml           structure Decimal :> DECIMAL
  decimal.mlb           MLton basis file for consumers
test/test.sml           assertion-based test suite
test/test.mlb           MLton basis file for the tests
Makefile                build + test (MLton and Poly/ML)
.github/workflows/ci.yml  CI on both compilers
```

## License

MIT. See [LICENSE](LICENSE).
