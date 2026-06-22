structure Decimal :> DECIMAL =
struct
  (* Representation: (coeff, scale) means coeff * 10^(-scale).
   * Invariant: scale >= 0. The sign lives in coeff. *)
  type decimal = IntInf.int * int
  type t = decimal

  datatype rounding = HALF_EVEN | HALF_UP | FLOOR | CEILING | TRUNCATE

  val zeroI : IntInf.int = 0
  val oneI  : IntInf.int = 1
  val tenI  : IntInf.int = 10

  fun pow10 (k : int) : IntInf.int = IntInf.pow (tenI, k)

  val zero : t = (zeroI, 0)
  val one  : t = (oneI, 0)

  fun fromIntInf n = (n, 0)
  fun fromInt i = (IntInf.fromInt i, 0)

  fun scale (_, s) = s
  fun coeff (c, _) = c

  (* Decide whether to round the truncated quotient away from zero.
   *   neg   : is the overall value negative?
   *   q     : truncated quotient magnitude (non-negative)
   *   r     : discarded remainder magnitude (non-negative, r < divisor)
   *   divisor: the 10^k we divided by (positive)
   * Returns true when the magnitude should be incremented by one. *)
  fun roundUp mode neg (q, r, divisor) =
      if r = zeroI then false
      else
        let
          (* Compare 2*r with divisor: LESS = below half, EQUAL = exactly half. *)
          val twice = IntInf.+ (r, r)
          val half = IntInf.compare (twice, divisor)
        in
          case mode of
              TRUNCATE => false
            | FLOOR => neg            (* toward -inf: round magnitude up only if negative *)
            | CEILING => not neg      (* toward +inf: round magnitude up only if positive *)
            | HALF_UP =>
                (case half of LESS => false | _ => true)
            | HALF_EVEN =>
                (case half of
                     LESS => false
                   | GREATER => true
                   | EQUAL =>
                       (* round to even: up only if the kept digit is odd *)
                       IntInf.mod (q, IntInf.fromInt 2) = oneI)
        end

  (* Rescale to exactly n fractional digits, rounding discarded digits. *)
  fun setScale mode n (c, s) =
      if n < 0 then raise General.Domain
      else if n = s then (c, s)
      else if n > s then (IntInf.* (c, pow10 (n - s)), n)
      else
        let
          val k = s - n
          val divisor = pow10 k
          val neg = c < zeroI
          val mag = IntInf.abs c
          val q = IntInf.div (mag, divisor)
          val r = IntInf.mod (mag, divisor)
          val q = if roundUp mode neg (q, r, divisor) then IntInf.+ (q, oneI) else q
          val signed = if neg then IntInf.~ q else q
        in
          (signed, n)
        end

  fun op ~ (c, s) = (IntInf.~ c, s)

  (* Align two values to a common scale (the max), returning both coeffs. *)
  fun align ((a, sa), (b, sb)) =
      let val s = Int.max (sa, sb)
          val a' = IntInf.* (a, pow10 (s - sa))
          val b' = IntInf.* (b, pow10 (s - sb))
      in (a', b', s) end

  fun op + (x, y) =
      let val (a, b, s) = align (x, y) in (IntInf.+ (a, b), s) end

  fun op - (x, y) =
      let val (a, b, s) = align (x, y) in (IntInf.- (a, b), s) end

  fun op * ((a, sa), (b, sb)) = (IntInf.* (a, b), Int.+ (sa, sb))

  (* Exact value of x / y, then rounded to n fractional digits.
   * Compute numerator scaled so the integer division yields n digits, plus a
   * guard remainder for rounding. *)
  fun op div mode n ((a, sa), (b, sb)) =
      if b = zeroI then raise General.Div
      else if n < 0 then raise General.Domain
      else
        let
          (* We want round( (a/10^sa) / (b/10^sb) ) to n places
           *   = round( a * 10^(sb - sa + n) / b ) * 10^(-n).
           * Let e = sb - sa + n. If e >= 0 scale the numerator up; otherwise
           * scale the denominator up. *)
          val e = Int.+ (Int.- (sb, sa), n)
          val (num, den) =
              if e >= 0 then (IntInf.* (a, pow10 e), b)
              else (a, IntInf.* (b, pow10 (Int.~ e)))
          (* Signed exact division with remainder; normalize sign so the
           * remainder magnitude is compared against |den|. *)
          val neg = (num < zeroI) <> (den < zeroI)
          val numA = IntInf.abs num
          val denA = IntInf.abs den
          val q = IntInf.div (numA, denA)
          val r = IntInf.mod (numA, denA)
          val q = if roundUp mode neg (q, r, denA) then IntInf.+ (q, oneI) else q
          val signed = if neg then IntInf.~ q else q
        in
          (signed, n)
        end

  (* Round to a named scale; an alias of setScale with a more discoverable name. *)
  fun roundTo mode n x = setScale mode n x

  (* Round to an integer (scale 0). *)
  fun round mode x = setScale mode 0 x

  fun floor x    = setScale FLOOR 0 x
  fun ceil x     = setScale CEILING 0 x
  fun truncate x = setScale TRUNCATE 0 x

  (* Integer power. A non-negative exponent raises the coefficient and scales
   * linearly, keeping the value exact. *)
  fun pow ((c, s) : t, e : int) : t =
      if e < 0 then raise General.Domain
      else if e = 0 then one
      else (IntInf.pow (c, e), Int.* (s, e))

  (* Floor of the integer square root via Newton's method on IntInf (exact, no
   * machine real). For n >= 0 returns the largest r with r*r <= n; the initial
   * guess 2^(ceil(bits/2)) is >= sqrt n, from which Newton decreases to the
   * floor. *)
  fun isqrt (n : IntInf.int) : IntInf.int =
      if n < zeroI then raise General.Domain
      else if n < (2 : IntInf.int) then n
      else
        let
          fun bits (k, acc) = if k = zeroI then acc else bits (IntInf.div (k, 2), Int.+ (acc, 1))
          val b = bits (n, 0)
          val g0 = IntInf.<< (oneI, Word.fromInt (Int.div (Int.+ (b, 1), 2)))
          fun iter x =
              let val y = IntInf.div (IntInf.+ (x, IntInf.div (n, x)), 2)
              in if y >= x then x else iter y end
        in
          iter g0
        end

  (* Square root truncated to n fractional digits. Using the identity
   * floor(sqrt q) = isqrt(floor q): the value is c*10^(-s), so sqrt scaled to
   * n places is floor(sqrt(c*10^(2n)/10^s)) = isqrt((c*10^(2n)) div 10^s). *)
  fun sqrt (n : int) ((c, s) : t) : t =
      if n < 0 orelse c < zeroI then raise General.Domain
      else
        let
          val radicand = IntInf.div (IntInf.* (c, pow10 (Int.* (2, n))), pow10 s)
        in
          (isqrt radicand, n)
        end

  fun compare (x, y) =
      let val (a, b, _) = align (x, y) in IntInf.compare (a, b) end

  fun equal (x, y) = compare (x, y) = EQUAL

  fun toReal (c, s) =
      Real.fromLargeInt c / Math.pow (10.0, Real.fromInt s)

  fun intInfToString (v : IntInf.int) : string =
      if v < zeroI then "-" ^ IntInf.toString (IntInf.~ v)
      else IntInf.toString v

  fun toString (c, s) =
      if s = 0 then intInfToString c
      else
        let
          val neg = c < zeroI
          val mag = IntInf.toString (IntInf.abs c)
          (* Pad with leading zeros so there are at least s+1 digits. *)
          val mag = if String.size mag <= s
                    then StringCvt.padLeft #"0" (Int.+ (s, 1)) mag
                    else mag
          val n = String.size mag
          val intPart = String.substring (mag, 0, Int.- (n, s))
          val fracPart = String.substring (mag, Int.- (n, s), s)
          val body = intPart ^ "." ^ fracPart
        in
          if neg then "-" ^ body else body
        end

  (* Parse an optionally-signed run of digits into (magnitude, isNegative). *)
  fun parseSign (s : string) : bool * string =
      if s = "" then (false, "")
      else
        let val c0 = String.sub (s, 0) in
          if c0 = #"-" orelse c0 = #"~" then (true, String.extract (s, 1, NONE))
          else if c0 = #"+" then (false, String.extract (s, 1, NONE))
          else (false, s)
        end

  fun allDigits s = s <> "" andalso CharVector.all Char.isDigit s

  (* Split on an 'e'/'E' exponent, returning (mantissa, exponentInt option-or-fail). *)
  fun splitExp (s : string) : (string * int) option =
      case String.fields (fn c => c = #"e" orelse c = #"E") s of
          [m] => SOME (m, 0)
        | [m, ex] =>
            let val (eneg, ebody) = parseSign ex in
              if allDigits ebody
              then SOME (m, Int.* ((if eneg then ~1 else 1), valOf (Int.fromString ebody)))
              else NONE
            end
        | _ => NONE

  fun fromString (str : string) : t option =
      case splitExp str of
          NONE => NONE
        | SOME (mant, exp) =>
            let
              val (neg, body) = parseSign mant
            in
              case String.fields (fn c => c = #".") body of
                  [whole] =>
                    if not (allDigits whole) then NONE
                    else applyExp neg whole "" exp
                | [whole, frac] =>
                    (* Allow an empty whole part (".5") but not an empty frac ("3."). *)
                    if not (allDigits frac) then NONE
                    else if whole <> "" andalso not (allDigits whole) then NONE
                    else applyExp neg whole frac exp
                | _ => NONE
            end

  (* Build a decimal from sign, integer-digit string, fractional-digit string,
   * and a base-10 exponent. *)
  and applyExp neg whole frac exp =
      let
        val digits = whole ^ frac
        val digits = if digits = "" then "0" else digits
      in
        case IntInf.fromString digits of
            NONE => NONE
          | SOME m =>
              let
                val m = if neg then IntInf.~ m else m
                (* scale from the fractional part, reduced by the exponent *)
                val s0 = Int.- (String.size frac, exp)
              in
                if s0 >= 0 then SOME (m, s0)
                else SOME (IntInf.* (m, pow10 (Int.~ s0)), 0)
              end
      end
end
