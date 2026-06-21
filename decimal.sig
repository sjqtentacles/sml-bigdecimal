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

  (* Compare and equate by value, so 2.5 and 2.50 are equal. *)
  val compare : t * t -> order
  val equal   : t * t -> bool

  val toReal   : t -> real                 (* approximation; real is not exact *)
  val toString : t -> string               (* "3.14", "-0.001", "100" *)
end
