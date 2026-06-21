(* Dependency-free test runner for the Decimal structure.
 * Prints one line per assertion and exits non-zero if any assertion fails. *)

structure D = Decimal

(* Bring the rounding constructors into scope unqualified. *)
val HALF_EVEN = D.HALF_EVEN
val HALF_UP = D.HALF_UP
val FLOOR = D.FLOOR
val CEILING = D.CEILING
val TRUNCATE = D.TRUNCATE

val passed = ref 0
val failed = ref 0

fun check (name : string) (cond : bool) : unit =
    if cond
    then (passed := !passed + 1; print ("ok   - " ^ name ^ "\n"))
    else (failed := !failed + 1; print ("FAIL - " ^ name ^ "\n"))

fun raisesDiv (thunk : unit -> 'a) : bool =
    (ignore (thunk ()); false) handle General.Div => true | _ => false

fun raisesDomain (thunk : unit -> 'a) : bool =
    (ignore (thunk ()); false) handle General.Domain => true | _ => false

(* parse a literal for brevity; tests assume fromString works, and there is a
 * dedicated fromString section to pin that down independently via fromInt. *)
fun d s = valOf (D.fromString s)

fun run () =
  let
    (* Construction and toString *)
    val () = check "zero prints 0" (D.toString D.zero = "0")
    val () = check "one prints 1" (D.toString D.one = "1")
    val () = check "fromInt 100 prints 100" (D.toString (D.fromInt 100) = "100")
    val () = check "fromInt ~7 prints -7" (D.toString (D.fromInt ~7) = "-7")

    (* fromString / toString round-trips and formatting *)
    val () = check "fromString 3.14" (D.toString (d "3.14") = "3.14")
    val () = check "fromString -0.001" (D.toString (d "-0.001") = "-0.001")
    val () = check "fromString 100" (D.toString (d "100") = "100")
    val () = check "fromString 0.0 keeps scale" (D.toString (d "0.0") = "0.0")
    val () = check "fromString .5 leading dot" (D.toString (d ".5") = "0.5")
    val () = check "fromString 1e3 exponent" (D.toString (d "1e3") = "1000")
    val () = check "fromString 2.5E-2 neg exponent" (D.toString (d "2.5E-2") = "0.025")
    val () = check "fromString ~7 tilde sign" (D.toString (d "~7") = "-7")
    val () = check "fromString +4.2 plus sign" (D.toString (d "+4.2") = "4.2")
    val () = check "fromString empty is NONE" (not (isSome (D.fromString "")))
    val () = check "fromString abc is NONE" (not (isSome (D.fromString "abc")))
    val () = check "fromString 1.2.3 is NONE" (not (isSome (D.fromString "1.2.3")))
    val () = check "fromString 3. is NONE" (not (isSome (D.fromString "3.")))

    (* scale and coeff accessors *)
    val () = check "scale of 3.14 = 2" (D.scale (d "3.14") = 2)
    val () = check "scale of 100 = 0" (D.scale (d "100") = 0)
    val () = check "coeff of 3.14 = 314" (D.coeff (d "3.14") = IntInf.fromInt 314)
    val () = check "coeff of -0.001 = -1" (D.coeff (d "-0.001") = IntInf.fromInt ~1)

    (* Addition / subtraction promote to max scale *)
    val () = check "2.5 + 1.00 = 3.50" (D.toString (D.+ (d "2.5", d "1.00")) = "3.50")
    val () = check "2.5 - 1.00 = 1.50" (D.toString (D.- (d "2.5", d "1.00")) = "1.50")
    val () = check "0.1 + 0.2 = 0.3 exactly" (D.toString (D.+ (d "0.1", d "0.2")) = "0.3")
    val () = check "5 + 0.25 = 5.25" (D.toString (D.+ (d "5", d "0.25")) = "5.25")
    val () = check "1.00 - 1.00 = 0.00" (D.toString (D.- (d "1.00", d "1.00")) = "0.00")

    (* Multiplication accumulates scale *)
    val () = check "1.5 * 2.0 = 3.00" (D.toString (D.* (d "1.5", d "2.0")) = "3.00")
    val () = check "0.1 * 0.1 = 0.01" (D.toString (D.* (d "0.1", d "0.1")) = "0.01")
    val () = check "12 * 12 = 144" (D.toString (D.* (d "12", d "12")) = "144")
    val () = check "-2.5 * 4 = -10.0" (D.toString (D.* (d "-2.5", d "4")) = "-10.0")

    (* Negation *)
    val () = check "negate 3.14 = -3.14" (D.toString (D.~ (d "3.14")) = "-3.14")
    val () = check "negate -3.14 = 3.14" (D.toString (D.~ (d "-3.14")) = "3.14")
    val () = check "negate 0.00 = 0.00" (D.toString (D.~ (d "0.00")) = "0.00")

    (* Division with explicit scale and rounding *)
    val () = check "1/3 scale 1 HALF_UP = 0.3"
                   (D.toString (D.div HALF_UP 1 (d "1", d "3")) = "0.3")
    val () = check "1/3 scale 4 HALF_UP = 0.3333"
                   (D.toString (D.div HALF_UP 4 (d "1", d "3")) = "0.3333")
    val () = check "2/3 scale 1 HALF_UP = 0.7"
                   (D.toString (D.div HALF_UP 1 (d "2", d "3")) = "0.7")
    val () = check "10/4 scale 2 = 2.50"
                   (D.toString (D.div HALF_UP 2 (d "10", d "4")) = "2.50")
    val () = check "1/3 scale 1 CEILING = 0.4"
                   (D.toString (D.div CEILING 1 (d "1", d "3")) = "0.4")
    val () = check "div by zero raises Div"
                   (raisesDiv (fn () => D.div HALF_UP 2 (d "1", d "0")))

    (* setScale rounding modes *)
    val () = check "setScale HALF_EVEN 0 of 2.5 = 2"
                   (D.toString (D.setScale HALF_EVEN 0 (d "2.5")) = "2")
    val () = check "setScale HALF_EVEN 0 of 3.5 = 4"
                   (D.toString (D.setScale HALF_EVEN 0 (d "3.5")) = "4")
    val () = check "setScale HALF_UP 0 of 2.5 = 3"
                   (D.toString (D.setScale HALF_UP 0 (d "2.5")) = "3")
    val () = check "setScale HALF_UP 0 of 2.4 = 2"
                   (D.toString (D.setScale HALF_UP 0 (d "2.4")) = "2")
    val () = check "setScale FLOOR 0 of 2.9 = 2"
                   (D.toString (D.setScale FLOOR 0 (d "2.9")) = "2")
    val () = check "setScale FLOOR 0 of -2.1 = -3"
                   (D.toString (D.setScale FLOOR 0 (d "-2.1")) = "-3")
    val () = check "setScale CEILING 0 of 2.1 = 3"
                   (D.toString (D.setScale CEILING 0 (d "2.1")) = "3")
    val () = check "setScale CEILING 0 of -2.9 = -2"
                   (D.toString (D.setScale CEILING 0 (d "-2.9")) = "-2")
    val () = check "setScale TRUNCATE 0 of 2.9 = 2"
                   (D.toString (D.setScale TRUNCATE 0 (d "2.9")) = "2")
    val () = check "setScale TRUNCATE 0 of -2.9 = -2"
                   (D.toString (D.setScale TRUNCATE 0 (d "-2.9")) = "-2")
    val () = check "setScale HALF_UP 0 of -2.5 = -3"
                   (D.toString (D.setScale HALF_UP 0 (d "-2.5")) = "-3")
    val () = check "setScale up 2.5 -> 2.500"
                   (D.toString (D.setScale HALF_UP 3 (d "2.5")) = "2.500")
    val () = check "setScale negative raises Domain"
                   (raisesDomain (fn () => D.setScale HALF_UP ~1 (d "2.5")))

    (* equal / compare by value across scales *)
    val () = check "2.5 equal 2.50" (D.equal (d "2.5", d "2.50"))
    val () = check "2.5 not equal 2.51" (not (D.equal (d "2.5", d "2.51")))
    val () = check "0 equal 0.00" (D.equal (d "0", d "0.00"))
    val () = check "compare 1.5 2.00 = LESS" (D.compare (d "1.5", d "2.00") = LESS)
    val () = check "compare 2.00 1.5 = GREATER" (D.compare (d "2.00", d "1.5") = GREATER)
    val () = check "compare 2.5 2.50 = EQUAL" (D.compare (d "2.5", d "2.50") = EQUAL)
    val () = check "compare -0.5 0.5 = LESS" (D.compare (d "-0.5", d "0.5") = LESS)

    (* toReal *)
    val () = check "toReal 0.5 = 0.5" (Real.== (D.toReal (d "0.5"), 0.5))
    val () = check "toReal -0.25 = -0.25" (Real.== (D.toReal (d "-0.25"), ~0.25))

    (* Big-coefficient arithmetic (no overflow; the IntInf base) *)
    val big = "123456789012345678901234567890.12"
    val () = check "big value round-trips" (D.toString (d big) = big)
    val () = check "big + big doubles coeff"
                   (D.toString (D.+ (d big, d big)) =
                    "246913578024691357802469135780.24")
  in
    print ("\n" ^ Int.toString (!passed) ^ " passed, "
           ^ Int.toString (!failed) ^ " failed\n");
    OS.Process.exit (if !failed = 0 then OS.Process.success else OS.Process.failure)
  end

val () = run ()
