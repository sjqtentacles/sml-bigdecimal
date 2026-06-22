(* demo.sml - arbitrary-precision decimal arithmetic on fixed values. Every
   result is printed with the library's own Decimal.toString (a scaled-integer
   model, no machine reals), so the output is identical on every run and on both
   compilers. *)

structure D = Decimal

fun dec s = valOf (D.fromString s)

val a = dec "3.14"
val b = dec "2.50"

val () = print ("a = " ^ D.toString a ^ ", b = " ^ D.toString b ^ "\n")
val () = print ("a + b            = " ^ D.toString (D.+ (a, b)) ^ "\n")
val () = print ("a - b            = " ^ D.toString (D.- (a, b)) ^ "\n")
val () = print ("a * b            = " ^ D.toString (D.* (a, b)) ^ "\n")
val () = print ("a / b (HALF_EVEN, 4dp) = "
                ^ D.toString (D.div D.HALF_EVEN 4 (a, b)) ^ "\n")
val () = print ("1.1 ^ 2          = " ^ D.toString (D.pow (dec "1.1", 2)) ^ "\n")
val () = print ("sqrt 2 (10 dp)   = " ^ D.toString (D.sqrt 10 (D.fromInt 2)) ^ "\n")
val () = print ("round HALF_EVEN 2.5 = " ^ D.toString (D.round D.HALF_EVEN (dec "2.5")) ^ "\n")
val () = print ("round HALF_UP   2.5 = " ^ D.toString (D.round D.HALF_UP (dec "2.5")) ^ "\n")
