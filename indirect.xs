/* This file is part of the indirect Perl module.
 * See http://search.cpan.org/dist/indirect/ */

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

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

/* ... Hints ............................................................... */

STATIC U32 indirect_hash = 0;

STATIC IV indirect_hint(pTHX) {
#define indirect_hint() indirect_hint(aTHX)
 SV *id;
#if I_HAS_PERL(5, 10, 0)
 id = Perl_refcounted_he_fetch(aTHX_ PL_curcop->cop_hints_hash,
                                     NULL,
                                     "indirect", 8,
                                     0,
                                     indirect_hash);
#else
 SV **val = hv_fetch(GvHV(PL_hintgv), "indirect", 8, indirect_hash);
 if (!val)
  return 0;
 id = *val;
#endif
 return (id && SvOK(id) && SvIOK(id)) ? SvIV(id) : 0;
}

/* ... op -> source position ............................................... */

STATIC HV *indirect_map = NULL;
STATIC const char *indirect_linestr = NULL;

/* We need (CHAR_BIT * sizeof(UV)) / 4 + 1 chars, but it's just better to take
 * a power of two */
#define OP2STR_BUF char buf[(CHAR_BIT * sizeof(UV)) / 2]
#define OP2STR(O)  (sprintf(buf, "%"UVxf, PTR2UV(O)))

STATIC void indirect_map_store(pTHX_ const OP *o, const char *src, SV *sv) {
#define indirect_map_store(O, S, N) indirect_map_store(aTHX_ (O), (S), (N))
 OP2STR_BUF;
 const char *pl_linestr;
 SV *val;

 /* When lex_inwhat is set, we're in a quotelike environment (qq, qr, but not q)
  * In this case the linestr has temporarly changed, but the old buffer should
  * still be alive somewhere. */

 if (!PL_lex_inwhat) {
  pl_linestr = SvPVX_const(PL_linestr);
  if (indirect_linestr != pl_linestr) {
   hv_clear(indirect_map);
   indirect_linestr = pl_linestr;
  }
 }

 val = newSVsv(sv);
 SvUPGRADE(val, SVt_PVIV);
 SvUVX(val) = PTR2UV(src);
 SvIOK_on(val);
 SvIsUV_on(val);
 if (!hv_store(indirect_map, buf, OP2STR(o), val, 0)) SvREFCNT_dec(val);
}

STATIC const char *indirect_map_fetch(pTHX_ const OP *o, SV ** const name) {
#define indirect_map_fetch(O, S) indirect_map_fetch(aTHX_ (O), (S))
 OP2STR_BUF;
 SV **val;

 if (indirect_linestr != SvPVX_const(PL_linestr))
  return NULL;

 val = hv_fetch(indirect_map, buf, OP2STR(o), 0);
 if (!val) {
  *name = NULL;
  return NULL;
 }

 *name = *val;
 return INT2PTR(const char *, SvUVX(*val));
}

STATIC void indirect_map_delete(pTHX_ const OP *o) {
#define indirect_map_delete(O) indirect_map_delete(aTHX_ (O))
 OP2STR_BUF;

 hv_delete(indirect_map, buf, OP2STR(o), G_DISCARD);
}

STATIC void indirect_map_clean_kids(pTHX_ const OP *o) {
#define indirect_map_clean_kids(O) indirect_map_clean_kids(aTHX_ (O))
 if (o->op_flags & OPf_KIDS) {
  const OP *kid = cUNOPo->op_first;
  for (; kid; kid = kid->op_sibling) {
   indirect_map_clean_kids(kid);
   indirect_map_delete(kid);
  }
 }
}

STATIC void indirect_map_clean(pTHX_ const OP *o) {
#define indirect_map_clean(O) indirect_map_clean(aTHX_ (O))
 indirect_map_clean_kids(o);
 indirect_map_delete(o);
}

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

STATIC const char indirect_msg[] = "Indirect call of method \"%s\" on object \"%s\"";

STATIC OP *(*indirect_old_ck_entersub)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_entersub(pTHX_ OP *o) {
 LISTOP *op;
 OP *om, *oo;
 IV hint = indirect_hint();

 o = CALL_FPTR(indirect_old_ck_entersub)(aTHX_ o);

 if (hint) {
  const char *pm, *po;
  SV *svm, *svo;
  oo = o;
  do {
   op = (LISTOP *) oo;
   if (!op->op_flags & OPf_KIDS)
    goto done;
   oo = op->op_first;
  } while (oo->op_type != OP_PUSHMARK);
  oo = oo->op_sibling;
  om = op->op_last;
  if (om->op_type == OP_METHOD)
   om = cUNOPx(om)->op_first;
  else if (om->op_type != OP_METHOD_NAMED)
   goto done;
  pm = indirect_map_fetch(om, &svm);
  po = indirect_map_fetch(oo, &svo);
  if (pm && po && pm < po) {
   const char *psvm = SvPV_nolen_const(svm), *psvo = SvPV_nolen_const(svo);
   if (hint == 2)
    croak(indirect_msg, psvm, psvo);
   else
    warn(indirect_msg, psvm, psvo);
  }
done:
  indirect_map_clean(o);
 }

 return o;
}

STATIC U32 indirect_initialized = 0;

/* --- XS ------------------------------------------------------------------ */

MODULE = indirect      PACKAGE = indirect

PROTOTYPES: DISABLE

BOOT:
{
 if (!indirect_initialized++) {
  PERL_HASH(indirect_hash, "indirect", 8);
  indirect_map = newHV();
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
