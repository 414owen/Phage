(def list (\() args))

(def quote (\\(a) a))

(def quotes (\\() args))

(def do (\ ()
  (if (= args ()) ()
    (if (= (cdr args) ()) (car args)
      (apply do (cdr args))))))

// (defunc fn \)
//    allows
// (def hi (\() 3))
//    to be written
// (fn hi () 3)

(def defunc (s\\ (name f)
  (call def name
    (call (ds\\ (g name ps)
      (call def name
        (cons g (cons ps rest)))) f))))

(def funcs
  (quote
    ((sfm   s\\)
     (fm     \\)
     (dsfm ds\\)
     (dfm   d\\)
     (sfn    s\)
     (fn      \)
     (dsfn  ds\)
     (dfn    d\))))

((s\ (l)
  (if (= l ()) ()
    (do (call defunc (caar l) (eval (cadar l)))
      (rec (cdr l)))))
  funcs)

(dsfm cond ()
  (if (= args ()) ()
    (if (eval (caar args))
      (eval (cadar args))
      (apply cond (cdr args)))))

(dsfn flip (_fn) (s\ (_a _b) (call _fn _b _a)))

(fn const (a b) a)

(sfn fold (zero fn lst)
  ((s\ (acc lst)
    (if (= lst ()) acc
      (rec (fn (car lst) acc) (cdr lst))))
    zero lst))

(def rev (fold () cons))

(fn pipe ()
  (def funs args)
  (fn piperec (params lst)
    (if (= lst ()) (car params)
    (rec (list (apply (car lst) params)) (cdr lst))))
  (\() (piperec args funs)))

(def rpipe (pipe list rev (apply pipe)))

(def dot rpipe)

(def nest (\(n el) (if (= n 0) el (nest (- n 1) (list el)))))

(fn homBinFunc (f) (s\ (a b)
  (fold a (flip f) (cons b rest))))

(fn ! (a) (if a false true))

(def | (homBinFunc (\(a b) (if a a b))))

(def & (homBinFunc (\(a b) (if a b a))))

(def -> (\(a b) (| (! a) b)))

(def ^  (\(a b) (& (| a b) (! (& a b)))))

(def ~= (\(a b) (! (^ a b))))

(fn all (l) (apply & (cons true l)))

(fn any (l) (apply | (cons false l)))

(fn choose (_f) (homBinFunc (\(_a _b) (if (call _f _a _b) _a _b))))

(fn > (a b) (< b a))

(fn >= (a b) (! (< a b)))

(fn <= (a b) (! (> a b)))

(def min (choose <))

(fn  minl (l) (fold (car l) min l))

(def max (choose >))

(fn  maxl (l) (fold (car l) max l))

(def init (dot rev (dot cdr rev)))

(def last (dot car rev))

(fn take (n lst)
  (if (| (= n 0) (= lst ())) ()
    (cons
      (car lst)
      (take (- n 1) (cdr lst)))))

(fn drop (n lst)
  (cond
    ((= lst ()) ())
    ((= n 0) lst)
    (true (drop (- n 1) (cdr lst)))))

(def !! (pipe drop car))

(fn block () (last args))

(sfn map (fun lst)
  (rev (fold ()
    (s\ (el acc) (cons (call fun el) acc)) lst)))

(dsfm mkHom (fname)
  (call def fname (homBinFunc (eval fname))))

// turn some boring binary functions into hella rad
// homogeneous binary functions
(map mkHom (quote (+ - / * % & ^ -> ~=)))

(def sum (fold 0 +))

(def prod (fold 1 *))

(def len (pipe (map (const 1)) sum))

(fn windows (n lst)
  (if (= lst ()) ()
    ((\(left lst)
      (if (= left (- 0 1)) ()
        (cons (take n lst)
           (rec (- left 1) (cdr lst)))))
      (- (len lst) n) lst)))

(fn chunks (n lst)
  (if (= lst ()) ()
    (cons (take n lst)
      (chunks n (drop n lst)))))

(fn filter (fun lst)
  (rev (fold () (\(el acc)
    (if (fun el) (cons el acc) acc)) lst)))

(fn caror (el lst) (if (= lst ()) el (car lst)))

(fn range (start end)
  (def step (caror 1 rest))
  (def fin (if (> step 0) >= <=))
  (if (fin start end) ()
    (cons start (range (+ start step) end step))))

(def upto (pipe (+ 1) (range 1)))

(fn intersperse (el lst)
  (cdr ((\(el lst)
    (if (= lst ()) ()
      (cons el (cons (car lst) (rec el (cdr lst))))))
     el lst)))

(def append (homBinFunc (\ (a b)
   (if (= a ()) b (cons (car a) (append (cdr a) b))))))

(def concat (\ (lsts)
  (apply append (cons () (cons () lsts)))))

(fn push (lst el)
  (apply append (cons lst (map list (cons el rest)))))

(def flatmap (pipe map concat))

(def intercalate (pipe intersperse concat))

(dfm let (tup)
  ((apply \ (cons (list (car tup)) rest)) (eval (cdar tup))))

(dfm lets (tups)
  ((s\ (l)
    (if (= l ()) ()
      (do (apply def (car l)) (rec (cdr l))))) tups)
  ((\ (l) (if (= l ()) ()
    (if (= (cdr l) ()) (eval (car l))
      (do (eval (car l)) (rec (cdr l)))))) rest))

(dsfm defs () (map (apply def) args))

(fm strs (a)
  (map str args))

(def oldprint print)

(fn print (arg)
  (oldprint arg)
  (if (= rest ()) arg
    (do (print (atom " ")) (apply print rest))))

(fn puts (arg)
  (apply print (map atom args)))

(fn printl ()
  (def a (apply print args))
  (puts "\n") a)

(fn putsl ()
  (def a (apply puts args))
  (puts "\n") a)

(fn zip (_)
  (if (any (map (= ()) args)) ()
    (cons (map car args) (apply zip (map cdr args)))))

(fn zipWith (fn _) (map (apply fn) (apply zip (cdr args))))

(fn transpose (lsts)
  (apply zip lsts))

(def rotate (pipe transpose rev))

/*

List comprehensions for Phage

format: (comp <list-exp1> <var1> <list-exp2> <var2> ... <result-exp>)

examples:
λ: (comp (list 1 2 3) x x)
>> (1 2 3)
λ: (comp (list 1 2 3) x (list 4 5 6) y (* x y))
>> (4 5 6 8 10 12 12 15 18)

*/

(fm comp (lst var exp)
  (dfn layer (_exp)
    (def _args args)
    (if (= rest ())
      (list (eval _exp))
      (concat
        (map
          ((\(_binding)
            (\(_el)
              (call def _binding _el)
              (apply layer (cddr _args)))) (car rest))
          (eval _exp)))))
  (apply layer args))

(def list? (sameType ""))
(def num? (sameType 0))
(def char? (sameType (car "hi")))
(def atom? (sameType (quote hi)))
(def bool? (sameType true))
(def form? (sameType car))

(fn even? (n) (= 0 (% n 2)))
(def odd? (pipe even? !))
