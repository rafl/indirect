/* This file is part of the indirect Perl module.
 * See http://search.cpan.org/dist/indirect/ */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define __PACKAGE__     "indirect"
#define __PACKAGE_LEN__ (sizeof(__PACKAGE__)-1)

/* --- Compatibility wrappers ---------------------------------------------- */

#ifndef NOOP
# define NOOP
#endif

#ifndef dNOOP
# define dNOOP
#endif

#ifndef SvPV_const
# define SvPV_const SvPV
#endif

#ifndef SvPV_nolen_const
# define SvPV_nolen_const SvPV_nolen
#endif

#ifndef SvPVX_const
# define SvPVX_const SvPVX
#endif

#ifndef sv_catpvn_nomg
# define sv_catpvn_nomg sv_catpvn
#endif

#ifndef mPUSHu
# define mPUSHu(U) PUSHs(sv_2mortal(newSVuv(U)))
#endif

#ifndef HvNAME_get
# define HvNAME_get(H) HvNAME(H)
#endif

#ifndef HvNAMELEN_get
# define HvNAMELEN_get(H) strlen(HvNAME_get(H))
#endif

#define I_HAS_PERL(R, V, S) (PERL_REVISION > (R) || (PERL_REVISION == (R) && (PERL_VERSION > (V) || (PERL_VERSION == (V) && (PERL_SUBVERSION >= (S))))))

#if I_HAS_PERL(5, 10, 0) || defined(PL_parser)
# ifndef PL_lex_inwhat
#  define PL_lex_inwhat PL_parser->lex_inwhat
# endif
# ifndef PL_linestr
#  define PL_linestr PL_parser->linestr
# endif
# ifndef PL_bufptr
#  define PL_bufptr PL_parser->bufptr
# endif
# ifndef PL_oldbufptr
#  define PL_oldbufptr PL_parser->oldbufptr
# endif
#else
# ifndef PL_lex_inwhat
#  define PL_lex_inwhat PL_Ilex_inwhat
# endif
# ifndef PL_linestr
#  define PL_linestr PL_Ilinestr
# endif
# ifndef PL_bufptr
#  define PL_bufptr PL_Ibufptr
# endif
# ifndef PL_oldbufptr
#  define PL_oldbufptr PL_Ioldbufptr
# endif
#endif

#ifndef I_WORKAROUND_REQUIRE_PROPAGATION
# define I_WORKAROUND_REQUIRE_PROPAGATION !I_HAS_PERL(5, 10, 1)
#endif

/* ... Thread safety and multiplicity ...................................... */

#ifndef I_MULTIPLICITY
# if defined(MULTIPLICITY) || defined(PERL_IMPLICIT_CONTEXT)
#  define I_MULTIPLICITY 1
# else
#  define I_MULTIPLICITY 0
# endif
#endif
#if I_MULTIPLICITY && !defined(tTHX)
# define tTHX PerlInterpreter*
#endif

#if I_MULTIPLICITY && defined(USE_ITHREADS) && defined(dMY_CXT) && defined(MY_CXT) && defined(START_MY_CXT) && defined(MY_CXT_INIT) && (defined(MY_CXT_CLONE) || defined(dMY_CXT_SV))
# define I_THREADSAFE 1
# ifndef MY_CXT_CLONE
#  define MY_CXT_CLONE \
    dMY_CXT_SV;                                                      \
    my_cxt_t *my_cxtp = (my_cxt_t*)SvPVX(newSV(sizeof(my_cxt_t)-1)); \
    Copy(INT2PTR(my_cxt_t*, SvUV(my_cxt_sv)), my_cxtp, 1, my_cxt_t); \
    sv_setuv(my_cxt_sv, PTR2UV(my_cxtp))
# endif
#else
# define I_THREADSAFE 0
# undef  dMY_CXT
# define dMY_CXT      dNOOP
# undef  MY_CXT
# define MY_CXT       indirect_globaldata
# undef  START_MY_CXT
# define START_MY_CXT STATIC my_cxt_t MY_CXT;
# undef  MY_CXT_INIT
# define MY_CXT_INIT  NOOP
# undef  MY_CXT_CLONE
# define MY_CXT_CLONE NOOP
#endif

/* --- Helpers ------------------------------------------------------------- */

/* ... Thread-safe hints ................................................... */

/* If any of those are true, we need to store the hint in a global table. */

#if I_THREADSAFE || I_WORKAROUND_REQUIRE_PROPAGATION

typedef struct {
 SV  *code;
#if I_WORKAROUND_REQUIRE_PROPAGATION
 I32  requires;
#endif
} indirect_hint_t;

#define PTABLE_NAME ptable_hints

#define PTABLE_VAL_FREE(V) \
   { indirect_hint_t *h = (V); SvREFCNT_dec(h->code); PerlMemShared_free(h); }

#define pPTBL  pTHX
#define pPTBL_ pTHX_
#define aPTBL  aTHX
#define aPTBL_ aTHX_

#include "ptable.h"

#define ptable_hints_store(T, K, V) ptable_hints_store(aTHX_ (T), (K), (V))
#define ptable_hints_free(T)        ptable_hints_free(aTHX_ (T))

#endif /* I_THREADSAFE || I_WORKAROUND_REQUIRE_PROPAGATION */

/* Define the op->str ptable here because we need to be able to clean it during
 * thread cleanup. */

#define PTABLE_NAME        ptable
#define PTABLE_VAL_FREE(V) SvREFCNT_dec(V)

#define pPTBL  pTHX
#define pPTBL_ pTHX_
#define aPTBL  aTHX
#define aPTBL_ aTHX_

#include "ptable.h"

#define ptable_store(T, K, V) ptable_store(aTHX_ (T), (K), (V))
#define ptable_clear(T)       ptable_clear(aTHX_ (T))
#define ptable_free(T)        ptable_free(aTHX_ (T))

#define MY_CXT_KEY __PACKAGE__ "::_guts" XS_VERSION

typedef struct {
#if I_THREADSAFE || I_WORKAROUND_REQUIRE_PROPAGATION
 ptable     *tbl; /* It really is a ptable_hints */
#endif
 ptable     *map;
 const char *linestr;
#if I_THREADSAFE
 tTHX        owner;
#endif
} my_cxt_t;

START_MY_CXT

#if I_THREADSAFE

STATIC void indirect_ptable_clone(pTHX_ ptable_ent *ent, void *ud_) {
 my_cxt_t        *ud = ud_;
 indirect_hint_t *h1 = ent->val;
 indirect_hint_t *h2 = PerlMemShared_malloc(sizeof *h2);

 *h2 = *h1;

 if (ud->owner != aTHX) {
  SV *val = h1->code;
  CLONE_PARAMS param;
  AV *stashes = (SvTYPE(val) == SVt_PVHV && HvNAME_get(val)) ? newAV() : NULL;
  param.stashes    = stashes;
  param.flags      = 0;
  param.proto_perl = ud->owner;
  h2->code = sv_dup(val, &param);
  if (stashes) {
   av_undef(stashes);
   SvREFCNT_dec(stashes);
  }
 }

 ptable_hints_store(ud->tbl, ent->key, h2);
 SvREFCNT_inc(h2->code);
}

STATIC void indirect_thread_cleanup(pTHX_ void *);

STATIC void indirect_thread_cleanup(pTHX_ void *ud) {
 int *level = ud;

 if (*level) {
  *level = 0;
  LEAVE;
  SAVEDESTRUCTOR_X(indirect_thread_cleanup, level);
  ENTER;
 } else {
  dMY_CXT;
  PerlMemShared_free(level);
  ptable_free(MY_CXT.map);
  ptable_hints_free(MY_CXT.tbl);
 }
}

#endif /* I_THREADSAFE */

#if I_THREADSAFE || I_WORKAROUND_REQUIRE_PROPAGATION

STATIC SV *indirect_tag(pTHX_ SV *value) {
#define indirect_tag(V) indirect_tag(aTHX_ (V))
 indirect_hint_t *h;
 dMY_CXT;

 value = SvOK(value) && SvROK(value) ? SvRV(value) : NULL;

 h = PerlMemShared_malloc(sizeof *h);
 h->code = SvREFCNT_inc(value);

#if I_WORKAROUND_REQUIRE_PROPAGATION
 {
  const PERL_SI *si;
  I32            requires = 0;

  for (si = PL_curstackinfo; si; si = si->si_prev) {
   I32 cxix;

   for (cxix = si->si_cxix; cxix >= 0; --cxix) {
    const PERL_CONTEXT *cx = si->si_cxstack + cxix;

    if (CxTYPE(cx) == CXt_EVAL && cx->blk_eval.old_op_type == OP_REQUIRE)
     ++requires;
   }
  }

  h->requires = requires;
 }
#endif

 /* We only need for the key to be an unique tag for looking up the value later.
  * Allocated memory provides convenient unique identifiers, so that's why we
  * use the value pointer as the key itself. */
 ptable_hints_store(MY_CXT.tbl, value, h);

 return newSVuv(PTR2UV(value));
}

STATIC SV *indirect_detag(pTHX_ const SV *hint) {
#define indirect_detag(H) indirect_detag(aTHX_ (H))
 indirect_hint_t *h;
 dMY_CXT;

 if (!(hint && SvOK(hint) && SvIOK(hint)))
  return NULL;

 h = ptable_fetch(MY_CXT.tbl, INT2PTR(void *, SvUVX(hint)));

#if I_WORKAROUND_REQUIRE_PROPAGATION
 {
  const PERL_SI *si;
  I32            requires = 0;

  for (si = PL_curstackinfo; si; si = si->si_prev) {
   I32 cxix;

   for (cxix = si->si_cxix; cxix >= 0; --cxix) {
    const PERL_CONTEXT *cx = si->si_cxstack + cxix;

    if (CxTYPE(cx) == CXt_EVAL && cx->blk_eval.old_op_type == OP_REQUIRE
                               && ++requires > h->requires)
     return NULL;
   }
  }
 }
#endif

 return h->code;
}

#else

STATIC SV *indirect_tag(pTHX_ SV *value) {
#define indirect_tag(V) indirect_tag(aTHX_ (V))
 UV tag = 0;

 if (SvOK(value) && SvROK(value)) {
  value = SvRV(value);
  SvREFCNT_inc(value);
  tag = PTR2UV(value);
 }

 return newSVuv(tag);
}

#define indirect_detag(H) (((H) && SvOK(H)) ? INT2PTR(SV *, SvUVX(H)) : NULL)

#endif /* I_THREADSAFE || I_WORKAROUND_REQUIRE_PROPAGATION */

STATIC U32 indirect_hash = 0;

STATIC SV *indirect_hint(pTHX) {
#define indirect_hint() indirect_hint(aTHX)
 SV *hint, *code;
#if I_HAS_PERL(5, 9, 5)
 hint = Perl_refcounted_he_fetch(aTHX_ PL_curcop->cop_hints_hash,
                                       NULL,
                                       __PACKAGE__, __PACKAGE_LEN__,
                                       0,
                                       indirect_hash);
#else
 SV **val = hv_fetch(GvHV(PL_hintgv), __PACKAGE__, __PACKAGE_LEN__,
                                                                 indirect_hash);
 if (!val)
  return 0;
 hint = *val;
#endif
 return indirect_detag(hint);
}

/* ... op -> source position ............................................... */

STATIC void indirect_map_store(pTHX_ const OP *o, const char *src, SV *sv) {
#define indirect_map_store(O, S, N) indirect_map_store(aTHX_ (O), (S), (N))
 dMY_CXT;
 SV *val;

 /* When lex_inwhat is set, we're in a quotelike environment (qq, qr, but not q)
  * In this case the linestr has temporarly changed, but the old buffer should
  * still be alive somewhere. */

 if (!PL_lex_inwhat) {
  const char *pl_linestr = SvPVX_const(PL_linestr);
  if (MY_CXT.linestr != pl_linestr) {
   ptable_clear(MY_CXT.map);
   MY_CXT.linestr = pl_linestr;
  }
 }

 val = newSVsv(sv);
 SvUPGRADE(val, SVt_PVIV);
 SvUVX(val) = PTR2UV(src);
 SvIOK_on(val);
 SvIsUV_on(val);
 SvREADONLY_on(val);

 ptable_store(MY_CXT.map, o, val);
}

STATIC const char *indirect_map_fetch(pTHX_ const OP *o, SV ** const name) {
#define indirect_map_fetch(O, S) indirect_map_fetch(aTHX_ (O), (S))
 dMY_CXT;
 SV *val;

 if (MY_CXT.linestr != SvPVX_const(PL_linestr))
  return NULL;

 val = ptable_fetch(MY_CXT.map, o);
 if (!val) {
  *name = NULL;
  return NULL;
 }

 *name = val;
 return INT2PTR(const char *, SvUVX(val));
}

STATIC void indirect_map_delete(pTHX_ const OP *o) {
#define indirect_map_delete(O) indirect_map_delete(aTHX_ (O))
 dMY_CXT;

 ptable_store(MY_CXT.map, o, NULL);
}

/* --- Check functions ----------------------------------------------------- */

STATIC const char *indirect_find(pTHX_ SV *sv, const char *s) {
#define indirect_find(N, S) indirect_find(aTHX_ (N), (S))
 STRLEN len;
 const char *p = NULL, *r = SvPV_const(sv, len);

 if (len >= 1 && *r == '$') {
  ++r;
  --len;
  s = strchr(s, '$');
  if (!s)
   return NULL;
 }

 p = strstr(s, r);
 while (p) {
  p += len;
  if (!isALNUM(*p))
   break;
  p = strstr(p + 1, r);
 }

 return p;
}

/* ... ck_const ............................................................ */

STATIC OP *(*indirect_old_ck_const)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_const(pTHX_ OP *o) {
 o = CALL_FPTR(indirect_old_ck_const)(aTHX_ o);

 if (indirect_hint()) {
  SV *sv = cSVOPo_sv;
  if (SvPOK(sv) && (SvTYPE(sv) >= SVt_PV)) {
   indirect_map_store(o, indirect_find(sv, PL_oldbufptr), sv);
   return o;
  }
 }

 indirect_map_delete(o);
 return o;
}

/* ... ck_rv2sv ............................................................ */

STATIC OP *(*indirect_old_ck_rv2sv)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_rv2sv(pTHX_ OP *o) {
 if (indirect_hint()) {
  OP *op = cUNOPo->op_first;
  SV *sv;
  const char *name = NULL, *s;
  STRLEN len;
  OPCODE type = (OPCODE) op->op_type;

  switch (type) {
   case OP_GV:
   case OP_GVSV: {
    GV *gv = cGVOPx_gv(op);
    name = GvNAME(gv);
    len  = GvNAMELEN(gv);
    break;
   }
   default:
    if ((PL_opargs[type] & OA_CLASS_MASK) == OA_SVOP) {
     SV *nsv = cSVOPx_sv(op);
     if (SvPOK(nsv) && (SvTYPE(nsv) >= SVt_PV))
      name = SvPV_const(nsv, len);
    }
  }
  if (!name)
   goto done;

  sv = sv_2mortal(newSVpvn("$", 1));
  sv_catpvn_nomg(sv, name, len);
  s = indirect_find(sv, PL_oldbufptr);
  if (!s) { /* If it failed, retry without the current stash */
   const char *stash = HvNAME_get(PL_curstash);
   STRLEN stashlen = HvNAMELEN_get(PL_curstash);

   if ((len < stashlen + 2) || strnNE(name, stash, stashlen)
       || name[stashlen] != ':' || name[stashlen+1] != ':') {
    /* Failed again ? Try to remove main */
    stash = "main";
    stashlen = 4;
    if ((len < stashlen + 2) || strnNE(name, stash, stashlen)
        || name[stashlen] != ':' || name[stashlen+1] != ':')
     goto done;
   }

   sv_setpvn(sv, "$", 1);
   stashlen += 2;
   sv_catpvn_nomg(sv, name + stashlen, len - stashlen);
   s = indirect_find(sv, PL_oldbufptr);
   if (!s)
    goto done;
  }

  o = CALL_FPTR(indirect_old_ck_rv2sv)(aTHX_ o);
  indirect_map_store(o, s, sv);
  return o;
 }

done:
 o = CALL_FPTR(indirect_old_ck_rv2sv)(aTHX_ o);

 indirect_map_delete(o);
 return o;
}

/* ... ck_padany ........................................................... */

STATIC OP *(*indirect_old_ck_padany)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_padany(pTHX_ OP *o) {
 o = CALL_FPTR(indirect_old_ck_padany)(aTHX_ o);

 if (indirect_hint()) {
  SV *sv;
  const char *s = PL_oldbufptr, *t = PL_bufptr - 1;

  while (s < t && isSPACE(*s)) ++s;
  if (*s == '$' && ++s <= t) {
   while (s < t && isSPACE(*s)) ++s;
   while (s < t && isSPACE(*t)) --t;
   sv = sv_2mortal(newSVpvn("$", 1));
   sv_catpvn_nomg(sv, s, t - s + 1);
   indirect_map_store(o, s, sv);
   return o;
  }
 }

 indirect_map_delete(o);
 return o;
}

/* ... ck_method ........................................................... */

STATIC OP *(*indirect_old_ck_method)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_method(pTHX_ OP *o) {
 if (indirect_hint()) {
  OP *op = cUNOPo->op_first;
  SV *sv;
  const char *s = indirect_map_fetch(op, &sv);
  if (!s) {
   sv = cSVOPx_sv(op);
   if (!SvPOK(sv) || (SvTYPE(sv) < SVt_PV))
    goto done;
   sv = sv_mortalcopy(sv);
   s  = indirect_find(sv, PL_oldbufptr);
  }
  o = CALL_FPTR(indirect_old_ck_method)(aTHX_ o);
  /* o may now be a method_named */
  indirect_map_store(o, s, sv);
  return o;
 }

done:
 o = CALL_FPTR(indirect_old_ck_method)(aTHX_ o);

 indirect_map_delete(o);
 return o;
}

/* ... ck_entersub ......................................................... */

STATIC OP *(*indirect_old_ck_entersub)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_entersub(pTHX_ OP *o) {
 SV *code = indirect_hint();

 o = CALL_FPTR(indirect_old_ck_entersub)(aTHX_ o);

 if (code) {
  const char *mpos, *opos;
  SV *mnamesv, *onamesv;
  OP *mop, *oop;
  LISTOP *lop;

  oop = o;
  do {
   lop = (LISTOP *) oop;
   if (!(lop->op_flags & OPf_KIDS))
    goto done;
   oop = lop->op_first;
  } while (oop->op_type != OP_PUSHMARK);
  oop = oop->op_sibling;
  mop = lop->op_last;

  if (!oop)
   goto done;

  switch (oop->op_type) {
   case OP_CONST:
   case OP_RV2SV:
   case OP_PADSV:
    break;
   default:
    goto done;
  }

  if (mop->op_type == OP_METHOD)
   mop = cUNOPx(mop)->op_first;
  else if (mop->op_type != OP_METHOD_NAMED)
   goto done;

  mpos = indirect_map_fetch(mop, &mnamesv);
  if (!mpos)
   goto done;

  opos = indirect_map_fetch(oop, &onamesv);
  if (!opos)
   goto done;

  if (mpos < opos) {
   SV     *file;
   line_t  line;
   dSP;

   ENTER;
   SAVETMPS;

   onamesv = sv_mortalcopy(onamesv);
   mnamesv = sv_mortalcopy(mnamesv);

#ifdef USE_ITHREADS
   file = sv_2mortal(newSVpv(CopFILE(&PL_compiling), 0));
#else
   file = sv_mortalcopy(CopFILESV(&PL_compiling));
#endif
   line = CopLINE(&PL_compiling);

   PUSHMARK(SP);
   EXTEND(SP, 4);
   PUSHs(onamesv);
   PUSHs(mnamesv);
   PUSHs(file);
   mPUSHu(line);
   PUTBACK;

   call_sv(code, G_VOID);

   PUTBACK;

   FREETMPS;
   LEAVE;
  }
 }

done:
 return o;
}

STATIC U32 indirect_initialized = 0;

/* --- XS ------------------------------------------------------------------ */

MODULE = indirect      PACKAGE = indirect

PROTOTYPES: ENABLE

BOOT:
{
 if (!indirect_initialized++) {
  HV *stash;

  MY_CXT_INIT;
  MY_CXT.map     = ptable_new();
  MY_CXT.linestr = NULL;
#if I_THREADSAFE || I_WORKAROUND_REQUIRE_PROPAGATION
  MY_CXT.tbl     = ptable_new();
#endif
#if I_THREADSAFE
  MY_CXT.owner   = aTHX;
#endif

  PERL_HASH(indirect_hash, __PACKAGE__, __PACKAGE_LEN__);

  indirect_old_ck_const    = PL_check[OP_CONST];
  PL_check[OP_CONST]       = MEMBER_TO_FPTR(indirect_ck_const);
  indirect_old_ck_rv2sv    = PL_check[OP_RV2SV];
  PL_check[OP_RV2SV]       = MEMBER_TO_FPTR(indirect_ck_rv2sv);
  indirect_old_ck_padany   = PL_check[OP_PADANY];
  PL_check[OP_PADANY]      = MEMBER_TO_FPTR(indirect_ck_padany);
  indirect_old_ck_method   = PL_check[OP_METHOD];
  PL_check[OP_METHOD]      = MEMBER_TO_FPTR(indirect_ck_method);
  indirect_old_ck_entersub = PL_check[OP_ENTERSUB];
  PL_check[OP_ENTERSUB]    = MEMBER_TO_FPTR(indirect_ck_entersub);

  stash = gv_stashpvn(__PACKAGE__, __PACKAGE_LEN__, 1);
  newCONSTSUB(stash, "I_THREADSAFE", newSVuv(I_THREADSAFE));
 }
}

#if I_THREADSAFE

void
CLONE(...)
PROTOTYPE: DISABLE
PREINIT:
 ptable *t;
 int    *level;
CODE:
 {
  my_cxt_t ud;
  dMY_CXT;
  ud.tbl   = t = ptable_new();
  ud.owner = MY_CXT.owner;
  ptable_walk(MY_CXT.tbl, indirect_ptable_clone, &ud);
 }
 {
  MY_CXT_CLONE;
  MY_CXT.map     = ptable_new();
  MY_CXT.linestr = NULL;
  MY_CXT.tbl     = t;
  MY_CXT.owner   = aTHX;
 }
 {
  level = PerlMemShared_malloc(sizeof *level);
  *level = 1;
  LEAVE;
  SAVEDESTRUCTOR_X(indirect_thread_cleanup, level);
  ENTER;
 }

#endif

SV *
_tag(SV *value)
PROTOTYPE: $
CODE:
 RETVAL = indirect_tag(value);
OUTPUT:
 RETVAL
