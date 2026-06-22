(* DECIMAL: arbitrary-precision decimal arithmetic (scaled-integer model).
 *
 * A value represents `coeff * 10^(-scale)` where `coeff : IntInf.int` carries
 * the sign and `scale : int >= 0` is the number of fractional digits. The
 * coefficient is arbitrary-precision (built on the Basis `IntInf`), so there
 * is no overflow.
 *
 * Unlike a rational, the scale is meaningful and preserved: 2.50 keeps its
 * trailing zero (scale 2) rather than collapsing to 2.5. This is what makes
 * the type suitable for money and human-facing decimal values.
 *
 * Operations that must discard digits (`setScale` to fewer places, `div`)
 * take an explicit `rounding` mode so precision is never lost silently.
 *)
signature DECIMAL =
sig
  type decimal
  type t = decimal

  datatype rounding = HALF_EVEN | HALF_UP | FLOOR | CEILING | TRUNCATE

  val zero : t
  val one  : t

  (* Construction. `fromString` accepts an optional sign ('-', '~', or '+'),
   * an integer part, an optional '.' with a fractional part, and an optional
   * 'e'/'E' exponent (e.g. "3.14", "-0.001", "100", "1e3", ".5", "2.5E-2");
   * returns NONE on malformed input. *)
  val fromInt    : int -> t
  val fromIntInf : IntInf.int -> t
  val fromString : string -> t option

  (* Scale control. `setScale` rescales to exactly `n` (>= 0) fractional
   * digits, rounding away discarded digits with the given mode; raises
   * General.Domain when n < 0. *)
  val scale    : t -> int
  val coeff    : t -> IntInf.int
  val setScale : rounding -> int -> t -> t

  val ~   : t -> t
  val +   : t * t -> t                     (* result scale = max of input scales *)
  val -   : t * t -> t                     (* result scale = max of input scales *)
  val *   : t * t -> t                     (* result scale = sum of input scales *)
  val div : rounding -> int -> t * t -> t  (* div to an explicit result scale; raises General.Div on zero divisor *)

  (* Rounding helpers built on the same `rounding` modes as setScale/div.
   *   roundTo  -- round to exactly n (>= 0) fractional digits (a named alias of
   *               setScale; raises General.Domain on n < 0).
   *   round    -- round to an integer (scale 0) with the given mode, e.g.
   *               round HALF_EVEN 2.5 = 2, round HALF_UP 2.5 = 3.
   *   floor / ceil / truncate -- round to an integer (scale 0) toward
   *               negative infinity / positive infinity / zero. *)
  val roundTo  : rounding -> int -> t -> t
  val round    : rounding -> t -> t
  val floor    : t -> t
  val ceil     : t -> t
  val truncate : t -> t

  (* Integer power with a non-negative exponent. pow (x, 0) = one; the result
   * scale is scale(x) * e, so the value is exact (e.g. pow (1.1, 2) = 1.21). A
   * negative exponent raises General.Domain (reciprocals are not exact in
   * general; use `div` with an explicit scale instead). *)
  val pow : t * int -> t

  (* Square root to n (>= 0) fractional digits via Newton's method on the
   * scaled IntInf coefficient (no machine real; deterministic). The result is
   * the value truncated toward zero at n places, i.e. result^2 <= x. A negative
   * operand or negative n raises General.Domain. e.g. sqrt 10 (fromInt 2)
   * = 1.4142135623. *)
  val sqrt : int -> t -> t

  (* Compare and equate by value, so 2.5 and 2.50 are equal. *)
  val compare : t * t -> order
  val equal   : t * t -> bool

  val toReal   : t -> real                 (* approximation; real is not exact *)
  val toString : t -> string               (* "3.14", "-0.001", "100" *)
end
