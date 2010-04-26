#lang scribble/doc
@(require "utils.ss")

@title[#:style 'toc]{Derived Utilities}

@local-table-of-contents[]

@; ------------------------------------------------------------

@include-section["define.scrbl"]

@; ------------------------------------------------------------

@section[#:tag "foreign:tagged-pointers"]{Tagged C Pointer Types}

The unsafe @scheme[cpointer-has-tag?] and @scheme[cpointer-push-tag!]
operations manage tags to distinguish pointer types.

@defproc*[([(_cpointer [tag any/c]
                       [ptr-type ctype? _xpointer]
                       [scheme-to-c (any/c . -> . any/c) values]
                       [c-to-scheme (any/c . -> . any/c) values])
            ctype]
           [(_cpointer/null [tag any/c]
                            [ptr-type ctype? _xpointer]
                            [scheme-to-c (any/c . -> . any/c) values]
                            [c-to-scheme (any/c . -> . any/c) values])
            ctype])]{

Construct a kind of a pointer that gets a specific tag when converted
to Scheme, and accept only such tagged pointers when going to C.  An
optional @scheme[ptr-type] can be given to be used as the base pointer
type, instead of @scheme[_pointer].

Pointer tags are checked with @scheme[cpointer-has-tag?] and changed
with @scheme[cpointer-push-tag!] which means that other tags are
preserved.  Specifically, if a base @scheme[ptr-type] is given and is
itself a @scheme[_cpointer], then the new type will handle pointers
that have the new tag in addition to @scheme[ptr-type]'s tag(s).  When
the tag is a pair, its first value is used for printing, so the most
recently pushed tag which corresponds to the inheriting type will be
displayed.

Note that tags are compared with @scheme[eq?] (or @scheme[memq]), which means
an interface can hide its value from users (e.g., not provide the
@scheme[cpointer-tag] accessor), which makes such pointers un-fake-able.

@scheme[_cpointer/null] is similar to @scheme[_cpointer] except that
it tolerates @cpp{NULL} pointers both going to C and back.  Note that
@cpp{NULL} pointers are represented as @scheme[#f] in Scheme, so they
are not tagged.}


@defform*[[(define-cpointer-type _id)
           (define-cpointer-type _id scheme-to-c-expr)
           (define-cpointer-type _id scheme-to-c-expr c-to-scheme-expr)]]{

A macro version of @scheme[_cpointer] and @scheme[_cpointer/null],
using the defined name for a tag string, and defining a predicate
too. The @scheme[_id] must start with @litchar{_}.

The optional expression produces optional arguments to @scheme[_cpointer].

In addition to defining @scheme[_id] to a type generated by
@scheme[_cpointer], @scheme[_id]@schemeidfont{/null} is bound to a
type produced by @scheme[_cpointer/null] type. Finally,
@schemevarfont{id}@schemeidfont{?}  is defined as a predicate, and
@schemevarfont{id}@schemeidfont{-tag} is defined as an accessor to
obtain a tag. The tag is the string form of @schemevarfont{id}.}

@defproc*[([(cpointer-has-tag? [cptr any/c] [tag any/c]) boolean?]
           [(cpointer-push-tag! [cptr any/c] [tag any/c]) void])]{

These two functions treat pointer tags as lists of tags.  As described
in @secref["foreign:pointer-funcs"], a pointer tag does not have any
role, except for Scheme code that uses it to distinguish pointers;
these functions treat the tag value as a list of tags, which makes it
possible to construct pointer types that can be treated as other
pointer types, mainly for implementing inheritance via upcasts (when a
struct contains a super struct as its first element).

The @scheme[cpointer-has-tag?] function checks whether if the given
@scheme[cptr] has the @scheme[tag]. A pointer has a tag @scheme[tag]
when its tag is either @scheme[eq?] to @scheme[tag] or a list that
contains (in the sense of @scheme[memq]) @scheme[tag].

The @scheme[cpointer-push-tag!] function pushes the given @scheme[tag]
value on @scheme[cptr]'s tags.  The main properties of this operation
are: (a) pushing any tag will make later calls to
@scheme[cpointer-has-tag?] succeed with this tag, and (b) the pushed tag
will be used when printing the pointer (until a new value is pushed).
Technically, pushing a tag will simply set it if there is no tag set,
otherwise push it on an existing list or an existing value (treated as
a single-element list).}

@; ------------------------------------------------------------

@section[#:tag "foreign:cvector"]{Safe C Vectors}

The @scheme[cvector] form can be used as a type C vectors (i.e., a
pointer to a memory block).

@defproc[(make-cvector [type ctype?][length exact-nonnegative-integer?]) cvector?]{

Allocates a C vector using the given @scheme[type] and
@scheme[length].}


@defproc[(cvector [type ctype?][val any/c] ...) cvector?]{

Creates a C vector of the given @scheme[type], initialized to the
given list of @scheme[val]s.}


@defproc[(cvector? [v any/c]) boolean?]{

Returns @scheme[#t] if @scheme[v] is a C vector, @scheme[#f] otherwise.}


@defproc[(cvector-length [cvec cvector?]) exact-nonnegative-integer?]{

Returns the length of a C vector.}


@defproc[(cvector-type [cvec cvector?]) ctype?]{

Returns the C type object of a C vector.}


@defproc[(cvector-ptr [cvec cvector?]) cpointer?]{

Returns the pointer that points at the beginning block of the given C vector.}


@defproc[(cvector-ref [cvec cvector?] [k exact-nonnegative-integer?]) any]{

References the @scheme[k]th element of the @scheme[cvec] C vector.
The result has the type that the C vector uses.}


@defproc[(cvector-set! [cvec cvector?][k exact-nonnegative-integer?][val any]) void?]{

Sets the @scheme[k]th element of the @scheme[cvec] C vector to
@scheme[val].  The @scheme[val] argument should be a value that can be
used with the type that the C vector uses.}


@defproc[(cvector->list [cvec cvector?]) list?]{

Converts the @scheme[cvec] C vector object to a list of values.}


@defproc[(list->cvector [lst list?][type ctype?]) cvector?]{

Converts the list @scheme[lst] to a C vector of the given
@scheme[type].}


@defproc[(make-cvector* [cptr any/c] [type ctype?]
                        [length exact-nonnegative-integer?])
                        cvector?]{

Constructs a C vector using an existing pointer object.  This
operation is not safe, so it is intended to be used in specific
situations where the @scheme[type] and @scheme[length] are known.}


@; ------------------------------------------------------------

@section[#:tag "homogeneous-vectors"]{Homogenous Vectors}

Homogenous vectors are similar to C vectors (see
@secref["foreign:cvector"]), except that they define different types
of vectors, each with a hard-wired type.

An exception is the @schemeidfont{u8} family of bindings, which are
just aliases for byte-string bindings: @scheme[make-u8vector],
@scheme[u8vector]. @scheme[u8vector?], @scheme[u8vector-length],
@scheme[u8vector-ref], @scheme[u8vector-set!],
@scheme[list->u8vector], @scheme[u8vector->list].

@(begin
   (require (for-syntax scheme/base))
   (define-syntax (srfi-4-vector stx)
     (syntax-case stx ()
       [(_ id elem)
        #'(srfi-4-vector/desc id elem 
                              "Like " (scheme make-vector) ", etc., but for " (scheme elem) " elements.")]))
   (define-syntax (srfi-4-vector/desc stx)
     (syntax-case stx ()
       [(_ id elem . desc)
        (let ([mk
               (lambda l
                 (datum->syntax
                  #'id
                  (string->symbol
                   (apply string-append
                          (map (lambda (i)
                                 (if (identifier? i)
                                     (symbol->string (syntax-e i))
                                     i))
                               l)))
                  #'id))])
          (with-syntax ([make (mk "make-" #'id "vector")]
                        [vecr (mk #'id "vector")]
                        [? (mk #'id "vector?")]
                        [length (mk #'id "vector-length")]
                        [ref (mk #'id "vector-ref")]
                        [! (mk #'id "vector-set!")]
                        [list-> (mk "list->" #'id "vector")]
                        [->list (mk #'id "vector->list")]
                        [->cpointer (mk #'id "vector->cpointer")]
                        [_vec (mk "_" #'id "vector")])
            #`(begin
               (defproc* ([(make [len exact-nonnegative-integer?]) ?]
                          [(vecr [val number?] (... ...)) ?]
                          [(? [v any/c]) boolean?]
                          [(length [vec ?]) exact-nonnegative-integer?]
                          [(ref [vec ?][k exact-nonnegative-integer?]) number?]
                          [(! [vec ?][k exact-nonnegative-integer?][val number?]) void?]
                          [(list-> [lst (listof number?)]) ?]
                          [(->list [vec ?]) (listof number?)]
                          [(->cpointer [vec ?]) cpointer?])
                 . desc)
               ;; Big pain: make up relatively-correct source locations
               ;; for pieces in the _vec definition:
               (defform* [#,(datum->syntax
                             #'_vec
                             (cons #'_vec
                                   (let loop ([l '(mode maybe-len)]
                                              [col (+ (syntax-column #'_vec)
                                                      (syntax-span #'_vec)
                                                      1)]
                                              [pos (+ (syntax-position #'_vec)
                                                      (syntax-span #'_vec)
                                                      1)])
                                     (if (null? l)
                                         null
                                         (let ([span (string-length (symbol->string (car l)))])
                                           (cons (datum->syntax
                                                  #'_vec
                                                  (car l)
                                                  (list (syntax-source #'_vec)
                                                        (syntax-line #'_vec)
                                                        col
                                                        pos
                                                        span))
                                                 (loop (cdr l)
                                                       (+ col 1 span)
                                                       (+ pos 1 span)))))))
                             (list (syntax-source #'_vec)
                                   (syntax-line #'_vec)
                                   (sub1 (syntax-column #'vec))
                                   (sub1 (syntax-position #'vec))
                                   10))
                           _vec]
                 "Like " (scheme _cvector) ", but for vectors of " (scheme elem) " elements."))))])))


@srfi-4-vector/desc[u8 _uint8]{

Like @scheme[_cvector], but for vectors of @scheme[_byte] elements. These are
aliases for @schemeidfont{byte} operations.}

@srfi-4-vector[s8 _int8]
@srfi-4-vector[s16 _int16]
@srfi-4-vector[u16 _uint16]
@srfi-4-vector[s32 _int32]
@srfi-4-vector[u32 _uint32]
@srfi-4-vector[s64 _int64]
@srfi-4-vector[u64 _uint64]
@srfi-4-vector[f32 _float]
@srfi-4-vector[f64 _double*]

@; ------------------------------------------------------------

@include-section["alloc.scrbl"]

@; ------------------------------------------------------------

@include-section["atomic.scrbl"]

@; ------------------------------------------------------------

@include-section["objc.scrbl"]
