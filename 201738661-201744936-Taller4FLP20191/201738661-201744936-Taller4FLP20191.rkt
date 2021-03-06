#lang eopl
; Taller 4 Fundamentos de lenguaje de programacion
; 
; 201738661-201744936-Taller4FLP
; 
; Developers:
; 
; Jorge Eduardo Mayor Fernandez
; Code: 201738661
; 
; Juan Sebastian Velasquez Acevedo
; Code: 201744936

;-------------------------------------------------------------------------------
;******************************************************************************************
;;;;; Full Interpreter

;; Definition BNF for language expressions:

;;<programa> := (un-programa) <expresion>


;;<expresion> := (numero-lit) <numero>
;;            := (texto-lit) "<letras>"
;;            := (primitiva-exp) <primitiva> [expresion (expresion*) (;)]
;;            := (identificador-lit) <identificador>
;;            := (condicional-exp) Si <expresion> entonces <expresion> sino <expresion> fin
;;            := (variableLocal-exp) declarar (<identificador> = <expresion> (;)) haga <expresion> fin
;;            := (procedimiento-exp) procedimiento [<identificador>*';'] haga <expresion> fin
;;            ::= (letrec) letrec {<identificador> (<identificador> ,)* = <expresion>}* in <expresion> 

;;<primitiva> := (suma) +
;;            := (resta) -
;;            := (div) /
;;            := (multiplicacion) *
;;            := (concat) concat
;;            := (length) length

;******************************************************************************************

;******************************************************************************************
;Lexical Specification

(define scanner-lexical-specification
  '((white-sp
     (whitespace) skip)
    (comment
     ("%" (arbno (not #\newline))) skip)
    (number
     (digit (arbno digit)) number)
    (number
     ("-" digit (arbno digit)) number)
    (number
     (digit "." (arbno digit)) number)
    (number
     ("-" digit "." (arbno digit)) number)
    (text
     (letter (arbno (or letter digit "?"))) string))
  )

;Syntactic specification (grammar)

(define grammar-syntatic-specification
  '((programa (expresion) un-programa)
    (expresion (number) numero-lit)
    (expresion (text) identificador-lit)
    (expresion ("\"" text "\"") texto-lit)
    (expresion (primitiva "[" expresion (arbno ";" expresion) "]") primitiva-exp)
    (expresion ("Si" expresion "entonces" expresion "sino" expresion "fin") condicional-exp)
    (expresion ("declarar" "(" (separated-list text "=" expresion ";") ")" "haga" expresion "fin") variableLocal-exp)
    (expresion ("procedimiento" "[" (separated-list text ";") "]" "haga" expresion "fin") procedimiento-exp)
    (expresion ("evaluar" expresion "enviando" "[" (separated-list expresion ";") "]" "fin") proc-evaluacion-exp)
    (expresion ("letrec" "{" (arbno text "(" (separated-list text ",") ")" "=" expresion) "}"  "in" expresion) letrec-exp)
    (primitiva ("+") suma)
    (primitiva ("-") resta)
    (primitiva ("*") multiplicacion)
    (primitiva ("/") div)
    (primitiva ("concat") concat)
    (primitiva ("length") length)
    )
  )

;Data types built automatically:

(sllgen:make-define-datatypes scanner-lexical-specification grammar-syntatic-specification)

;Test
(define show-the-datatypes
  (lambda () (sllgen:list-define-datatypes scanner-lexical-specification grammar-syntatic-specification)))
(show-the-datatypes)
;*******************************************************************************************
;Parser, Scanner, Interface

;The FrontEnd (Lexicon Analyzer (scanner) y syntactic (parser) integrados)

(define scan&parse
  (sllgen:make-string-parser scanner-lexical-specification grammar-syntatic-specification))

;Lexicon Analyzer (Scanner)

(define just-scan
  (sllgen:make-string-scanner scanner-lexical-specification grammar-syntatic-specification))

; Tests
(scan&parse "-[55]")
(scan&parse "-[5;1]")
(scan&parse "\"ghf\"")

;The Interpreter (FrontEnd + evaluation + sign for reading )

(define interpreter
  (sllgen:make-rep-loop "--> "
                        (lambda (pgm) (eval-program  pgm))
                        (sllgen:make-stream-parser 
                         scanner-lexical-specification
                         grammar-syntatic-specification)))

;*******************************************************************************************
;eval-program: <programa> -> number |string | symbol
; Purpose: function that evaluates a program 

(define eval-program
  (lambda (pgm)
    (cases programa pgm
      (un-programa (body)
                   (eval-expression body (init-env))))))

; Initial Enviroment
(define init-env
  (lambda ()
    (extend-env
     '(a b c pi)
     '(1 2 3 3.1416)
     (empty-env))))

;valor-verdad? determines whether a given value corresponds to a false or true Boolean value
(define valor-verdad?
  (lambda (x)
    (not (zero? x))))

;eval-expression: <expresion> <ambiente>-> number || string || cerradura
; Purpose: Evaluate the expression using cases to determine which datatype is,
; it is used in eval-program. 
(define eval-expression
  (lambda (exp env)
    (cases expresion exp
      (texto-lit (datum)
                 datum)
      (numero-lit (characters)
                  characters)
      (identificador-lit (identificador)
                         (buscar-variable env (string->symbol identificador)))
      (condicional-exp (predicado expVerdad expFalso)
                       (if (valor-verdad? (eval-expression predicado env))
                           (eval-expression expVerdad env)
                           (eval-expression expFalso env)))
      (variableLocal-exp (ids rands body)
                         (let ([args (eval-rands rands env)])
                           (eval-expression body (extendido (listOfString->listOfSymbols ids) args env))
                           )
                         )
      (procedimiento-exp (ids body)
                         (cerradura (listOfString->listOfSymbols ids ) body env))
      (proc-evaluacion-exp (rator rands)
                           (let ([proc (eval-expression rator env)]
                                 [args (eval-rands rands env)])
                             (if (procedimiento? proc)
                                 (apply-procedure proc args)
                                 ("Attemp to apply non-procedure ~s" proc))
                             )
                           )
      (letrec-exp (proc-names ids bodies letrec-body)
                  (eval-expression letrec-body
                                   (recursively-extended-env-record (listOfString->listOfSymbols proc-names ) (listOfListString->listOfListSymbols ids ) bodies env))
                  )
      (primitiva-exp (prim exp rands)
                     (if (null? rands)
                         (apply-primitive prim (list (eval-expression exp env)))
                         (apply-primitive prim (cons (eval-expression exp env) (map (lambda (x) (eval-expression x env)) rands)))
                         )
                     )
      )
    )
  )


; auxiliary functions to apply eval-expression to each element of a
; list of operands (expressions)
(define eval-rands
  (lambda (rands env)
    (map (lambda (x) (eval-rand x env)) rands)))

(define eval-rand
  (lambda (rand env)
    (eval-expression rand env)))

;Auxiliary functions to convert lists of strings to lists of symbols
(define listOfString->listOfSymbols
  (lambda (ids)
    (cond [(null? ids) empty]
          [else (cons (string->symbol (car ids)) (listOfString->listOfSymbols (cdr ids)))])))

(define listOfListString->listOfListSymbols
  (lambda (ids)
    (cond [(null? ids) empty]
          [else (cons (listOfString->listOfSymbols (car ids)) (listOfListString->listOfListSymbols (cdr ids)))])))

;apply-primitive: <primitiva> <list-of-expression> -> number || string
;Purpose: Operates the list of expression(at least one expression acording to grammar)
; depending on what primitive is, which is identified with cases.
; This procedure is used in  eval-expression.

(define apply-primitive
  (lambda (prim args)
    (if (null? (cdr args))
        (cases primitiva prim
          (length () (string-length (car args)))
          (default (car args))
          )
        (cases primitiva prim
          (suma () (+ (car args) (apply-primitive prim (cdr args))))
          (resta () (- (car args) (apply-primitive prim (cdr args))))
          (multiplicacion () (* (car args) (apply-primitive prim (cdr args))))
          (div () (/ (car args) (apply-primitive prim (cdr args))))
          (concat () (string-append (car args) (apply-primitive prim (cdr args))))
          (length ()  (string-length (car args)))
          )
        )
    )
  )

;*******************************************************************************************
;Environments

;<ambiente>:= (vacio) '()
;            (extendido) (lista-simbolos) (lista-expresiones) <ambiente>

;definition of the type of environment data (ambiente)
(define-datatype ambiente ambiente?
  (vacio)
  (extendido (syms (list-of symbol?))
                       (vals (list-of scheme-value?))
                       (env ambiente?))
  (recursively-extended-env-record (proc-names (list-of symbol?))
                                   (idss (list-of (list-of symbol?)))
                                   (bodies (list-of expresion?))
                                   (env ambiente?))
  )

(define scheme-value? (lambda (v) #t))

;empty-env:  -> ambiente
;; function that creates an empty environment(vacio)
(define empty-env  
  (lambda ()
    (vacio)))       ;called the empty environment builder 


;extend-env: <list-of symbols> <list-of numbers> ambiente -> ambiente
; function that creates an extended environment
(define extend-env
  (lambda (syms vals env)
    (extendido syms vals env))) 

;buscar-variable: <ambiente><symbol>->value
;function that looks for a symbol in an environment
(define buscar-variable
  (lambda (env sym)
    (cases ambiente env
      (vacio ()
                        (eopl:error 'buscar-variable "No binding for ~s" sym))
      (extendido (syms vals env)
                           (let ((pos (list-find-position sym syms)))
                             (if (number? pos)
                                 (list-ref vals pos)
                                 (buscar-variable env sym))))
      (recursively-extended-env-record (proc-names idss bodies old-env)
                                       (let ([pos (list-find-position sym proc-names)])
                                         (if (number? pos)
                                             (cerradura (list-ref idss pos)
                                                        (list-ref bodies pos)
                                                        env)
                                             (buscar-variable old-env sym))))
      )
    )
  )


;****************************************************************************************
; Auxiliary functions

; auxiliary functions to find the position of a symbol
; in the list of symbols of an environment

(define list-find-position
  (lambda (sym los)
    (list-index (lambda (sym1) (eqv? sym1 sym)) los)))

(define list-index
  (lambda (pred ls)
    (cond
      ((null? ls) #f)
      ((pred (car ls)) 0)
      (else (let ((list-index-r (list-index pred (cdr ls))))
              (if (number? list-index-r)
                  (+ list-index-r 1)
                  #f))))))

;******************************************************************************************
;Procediminetos

(define-datatype procedimiento procedimiento?
  (cerradura
   (ids (list-of symbol?))
   (body expresion?)
   (env ambiente?))
  )

(define apply-procedure
  (lambda (proc args)
    (cases procedimiento proc
      (cerradura (ids body env)
                 (eval-expression body (extendido ids args env)))
      )
    )
  )
;******************************************************************************************

(interpreter)


;Tests:
;Si +[2;3] entonces 2 sino 3 fin
;Si -[3;3] entonces 2 sino 3 fin
;declarar (x=2;y=3;a=7) haga +[a;-[x;y]] fin
;declarar (x=2;y=3;a=7) haga a fin
;declarar(x=2;y=3) haga a fin
;procedimiento [x;y;z] haga +[x;y;z] fin
;declarar (x=2;y=3) haga declarar (t=4;a = procedimiento[x;y;z] haga +[x;y;z] fin) haga evaluar a enviando [1;2;3] fin fin fin
;declarar (x=2;y=3) haga declarar (t=4; a = procedimiento[x;y;z] haga +[x;y;z] fin) haga +[x;y; evaluar a enviando [1;2;3] fin] fin fin



;IMPLEMENTACION DEL LENGUAJE DE PROGRAMACION
;-------------------------------------------------------------------
;PUNTO 12 A: area de un circulo de radio 4
;-------------------------------------------------------------------
;declarar (area=procedimiento[r] haga *[pi;r;r] fin) haga evaluar area enviando [4] fin fin
;-------------------------------------------------------------------

;-------------------------------------------------------------------
;PUNTO 12 B: factorial de un numero n de forma recursiva
;-------------------------------------------------------------------
;letrec {
;factorial (n) = Si n entonces *[ n; evaluar factorial enviando [-[n;1]] fin] sino 1 fin}
;in
;evaluar factorial enviando [6] fin
;-------------------------------------------------------------------

;-------------------------------------------------------------------
;PUNTO 12 C: multiplicacion con sumas anidadas
;-------------------------------------------------------------------
;letrec {
;multiplicacion (x,y) = Si -[x;1] entonces +[ y; evaluar multiplicacion enviando [-[x;1];y] fin] sino y fin}
;in
;evaluar multiplicacion enviando [3;4] fin
;-------------------------------------------------------------------


