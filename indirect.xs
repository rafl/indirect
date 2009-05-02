/* This file is part of the indirect Perl module.
 * See http://search.cpan.org/dist/indirect/ */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define __PACKAGE__     "indirect"
#define __PACKAGE_LEN__ (sizeof(__PACKAGE__)-1)

/* --- Compatibility wrappers ---------------------------------------------- */

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

#ifndef HvNAME_get
# define HvNAME_get(H) HvNAME(H)
#endif

#ifndef HvNAMELEN_get
# define HvNAMELEN_get(H) strlen(HvNAME_get(H))
#endif

#ifndef SvIS_FREED
# define SvIS_FREED(sv) ((sv)->sv_flags == SVTYPEMASK)
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
#endif

/* --- Helpers ------------------------------------------------------------- */

/* ... Thread-safe hints ................................................... */

#if I_THREADSAFE

#define PTABLE_NAME        ptable_hints
#define PTABLE_VAL_FREE(V) if ((V) && !SvIS_FREED((SV *) (V))) SvREFCNT_dec(V)

#define pPTBL  pTHX
#define pPTBL_ pTHX_
#define aPTBL  aTHX
#define aPTBL_ aTHX_

#include "ptable.h"

#define ptable_hints_store(T, K, V) ptable_hints_store(aTHX_ (T), (K), (V))
#define ptable_hints_free(T)        ptable_hints_free(aTHX_ (T))

#define MY_CXT_KEY __PACKAGE__ "::_guts" XS_VERSION

typedef struct {
 ptable *tbl;
 tTHX    owner;
} my_cxt_t;

START_MY_CXT

STATIC void indirect_ptable_hints_clone(pTHX_ ptable_ent *ent, void *ud_) {
 my_cxt_t *ud  = ud_;
 SV       *val = ent->val;

 if (ud->owner != aTHX) {
  CLONE_PARAMS param;
  AV *stashes = (SvTYPE(val) == SVt_PVHV && HvNAME_get(val)) ? newAV() : NULL;
  param.stashes    = stashes;
  param.flags      = 0;
  param.proto_perl = ud->owner;
  val = sv_dup(val, &param);
  if (stashes) {
   av_undef(stashes);
   SvREFCNT_dec(stashes);
  }
 }

 ptable_hints_store(ud->tbl, ent->key, val);
 SvREFCNT_inc(val);
}

STATIC void indirect_thread_cleanup(pTHX_ void *);

STATIC void indirect_thread_cleanup(pTHX_ void *ud) {
 int *level = ud;
 SV  *id;

 if (*level) {
  *level = 0;
  LEAVE;
  SAVEDESTRUCTOR_X(indirect_thread_cleanup, level);
  ENTER;
 } else {
  dMY_CXT;
  PerlMemShared_free(level);
  ptable_hints_free(MY_CXT.tbl);
 }
}

STATIC SV *indirect_tag(pTHX_ SV *value) {
#define indirect_tag(V) indirect_tag(aTHX_ (V))
 dMY_CXT;

 value = SvOK(value) && SvROK(value) ? SvRV(value) : NULL;
 /* We only need for the key to be an unique tag for looking up the value later.
  * Allocated memory provides convenient unique identifiers, so that's why we
  * use the value pointer as the key itself. */
 ptable_hints_store(MY_CXT.tbl, value, value);
 SvREFCNT_inc(value);

 return newSVuv(PTR2UV(value));
}

STATIC SV *indirect_detag(pTHX_ const SV *hint) {
#define indirect_detag(H) indirect_detag(aTHX_ (H))
 void *tag;
 SV   *value;

 if (!hint || !SvOK(hint) || !SvIOK(hint))
  croak("Wrong hint");

 tag = INT2PTR(void *, SvIVX(hint));
 {
  dMY_CXT;
  value = ptable_fetch(MY_CXT.tbl, tag);
 }

 return value;
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

#define indirect_detag(H) INT2PTR(SV *, SvUVX(H))

#endif /* I_THREADSAFE */

STATIC U32 indirect_hash = 0;

STATIC SV *indirect_hint(pTHX) {
#define indirect_hint() indirect_hint(aTHX)
 SV *id;
#if I_HAS_PERL(5, 10, 0)
 id = Perl_refcounted_he_fetch(aTHX_ PL_curcop->cop_hints_hash,
                                     NULL,
                                     __PACKAGE__, __PACKAGE_LEN__,
                                     0,
                                     indirect_hash);
#else
 SV **val = hv_fetch(GvHV(PL_hintgv), __PACKAGE__, __PACKAGE_LEN__,
                                                                 indirect_hash);
 if (!val)
  return 0;
 id = *val;
#endif
 return (id && SvOK(id)) ? id : NULL;
}

/* ... op -> source position ............................................... */

#define PTABLE_NAME        ptable_map
#define PTABLE_VAL_FREE(V) SvREFCNT_dec(V)

#define pPTBL  pTHX
#define pPTBL_ pTHX_
#define aPTBL  aTHX
#define aPTBL_ aTHX_

#include "ptable.h"

#define ptable_map_store(T, K, V) ptable_map_store(aTHX_ (T), (K), (V))
#define ptable_map_clear(T)       ptable_map_clear(aTHX_ (T))

STATIC ptable *indirect_map = NULL;

STATIC const char *indirect_linestr = NULL;

STATIC void indirect_map_store(pTHX_ const OP *o, const char *src, SV *sv) {
#define indirect_map_store(O, S, N) indirect_map_store(aTHX_ (O), (S), (N))
 SV *val;

 /* When lex_inwhat is set, we're in a quotelike environment (qq, qr, but not q)
  * In this case the linestr has temporarly changed, but the old buffer should
  * still be alive somewhere. */

 if (!PL_lex_inwhat) {
  const char *pl_linestr = SvPVX_const(PL_linestr);
  if (indirect_linestr != pl_linestr) {
   ptable_map_clear(indirect_map);
   indirect_linestr = pl_linestr;
  }
 }

 val = newSVsv(sv);
 SvUPGRADE(val, SVt_PVIV);
 SvUVX(val) = PTR2UV(src);
 SvIOK_on(val);
 SvIsUV_on(val);

 ptable_map_store(indirect_map, o, val);
}

STATIC const char *indirect_map_fetch(pTHX_ const OP *o, SV ** const name) {
#define indirect_map_fetch(O, S) indirect_map_fetch(aTHX_ (O), (S))
 SV *val;

 if (indirect_linestr != SvPVX_const(PL_linestr))
  return NULL;

 val = ptable_fetch(indirect_map, o);
 if (!val) {
  *name = NULL;
  return NULL;
 }

 *name = val;
 return INT2PTR(const char *, SvUVX(val));
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
  if (SvPOK(sv) && (SvTYPE(sv) >= SVt_PV))
   indirect_map_store(o, indirect_find(sv, PL_oldbufptr), sv);
 }

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
 return CALL_FPTR(indirect_old_ck_rv2sv)(aTHX_ o);
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
  }
 }

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
 return CALL_FPTR(indirect_old_ck_method)(aTHX_ o);
}

/* ... ck_entersub ......................................................... */

STATIC OP *(*indirect_old_ck_entersub)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_entersub(pTHX_ OP *o) {
 SV *hint = indirect_hint();

 o = CALL_FPTR(indirect_old_ck_entersub)(aTHX_ o);

 if (hint) {
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
   SV *code = indirect_detag(hint);

   if (hint) {
    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    EXTEND(SP, 2);
    PUSHs(onamesv);
    PUSHs(mnamesv);
    PUTBACK;

    call_sv(code, G_VOID);

    PUTBACK;

    FREETMPS;
    LEAVE;
   }
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
#if I_THREADSAFE
  MY_CXT_INIT;
  MY_CXT.tbl   = ptable_new();
  MY_CXT.owner = aTHX;
#endif

  indirect_map = ptable_new();

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
  ptable_walk(MY_CXT.tbl, indirect_ptable_hints_clone, &ud);
 }
 {
  MY_CXT_CLONE;
  MY_CXT.tbl   = t;
  MY_CXT.owner = aTHX;
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
