(lang dune 3.0)
(name rae)
(version 0.1.0)

(using menhir 2.1)

(package
 (name rae)
 (depends
  (ocaml (>= 4.14.0))
  (dune (>= 3.0.0))
  (menhir (>= 20200211))
  (ppx_deriving (>= 5.1))))
