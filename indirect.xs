#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#ifndef SvPVX_const
# define SvPVX_const SvPVX
#endif

STATIC U32 indirect_initialized = 0;
STATIC U32 indirect_hash = 0;

STATIC const char indirect_msg[] = "Indirect call of method \"%s\" on object \"%s\"";

STATIC HV *indirect_map = NULL;
STATIC const char *indirect_linestr = NULL;

STATIC UV indirect_hint(pTHX) {
#define indirect_hint() indirect_hint(aTHX)
 SV *id = Perl_refcounted_he_fetch(aTHX_ PL_curcop->cop_hints_hash,
                                         NULL,
                                         "indirect", 8,
                                         0,
                                         indirect_hash);
 return SvOK(id) ? SvUV(id) : 0;
}

STATIC void indirect_map_store(pTHX_ const OP *o, const char *src, SV *sv) {
#define indirect_map_store(O, S, N) indirect_map_store(aTHX_ (O), (S), (N))
 char buf[32];
 const char *pl_linestr;
 SV *val;

 /* When lex_inwhat is set, we're in a quotelike environment (qq, qr, but not q)
  * In this case the linestr has temporarly changed, but the old buffer should
  * still be alive somewhere. */

 if (!PL_parser->lex_inwhat) {
  pl_linestr = SvPVX_const(PL_parser->linestr);
  if (indirect_linestr != pl_linestr) {
   hv_clear(indirect_map);
   indirect_linestr = pl_linestr;
  }
 }

 val = newSVsv(sv);
 SvUPGRADE(val, SVt_PVIV);
 SvUVX(val) = PTR2UV(src);
 if (!hv_store(indirect_map, buf, sprintf(buf, "%u", PTR2UV(o)), val, 0))
  SvREFCNT_dec(val);
}

STATIC const char *indirect_map_fetch(pTHX_ const OP *o, SV **name) {
#define indirect_map_fetch(O, S) indirect_map_fetch(aTHX_ (O), (S))
 char buf[32];
 SV **val;

 if (indirect_linestr != SvPVX(PL_parser->linestr))
  return NULL;

 val = hv_fetch(indirect_map, buf, sprintf(buf, "%u", PTR2UV(o)), 0);
 if (!val) {
  *name = NULL;
  return NULL;
 }

 *name = *val;
 return INT2PTR(const char *, SvUVX(*val));
}

STATIC UV indirect_intuit(const char *meth, const char *obj) {
 const char *s;
 int indirect = 0, quotelike = 0;

 for (s = meth; s < obj; ++s) {
  switch (*s) {
   case ',':
   case '(':
   case '=':
   case '\'':
   case '"':
   case '`':
    return 0;
   case '-':
    indirect = 1;
    break;
   case '>':
    if (indirect)
     return 0;
    break;
   case 'q':
    indirect = 0;
    if (quotelike == 1)
     quotelike = 2;
    break;
   case 'w':
   case 'r':
   case 'x':
    indirect = 0;
    if (quotelike != 2)
     quotelike = 0;
    break;
   default:
    indirect = 0;
    if (isSPACE(*s))
     quotelike = 1;
    else if (quotelike == 2 && !isALNUM(*s))
     return 0;
    else
     quotelike = 0;
  }
 }

 return 1;
}

STATIC const char *indirect_find(pTHX_ SV *sv, const char *s) {
#define indirect_find(N, S) indirect_find(aTHX_ (N), (S))
 STRLEN len;
 const char *p = NULL, *r = SvPV_const(sv, len);

 if (!len)
  return s;

 p = strstr(s, r);
 while (p) {
  p += len;
  if (!isALNUM(*p))
   break;
  p = strstr(p + 1, r);
 }

 return p;
}

STATIC OP *(*indirect_old_ck_const)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_const(pTHX_ OP *o) {
 if (indirect_hint()) {
  SV *sv = cSVOPo_sv;
  if (SvPOK(sv) && (SvTYPE(sv) >= SVt_PV))
   indirect_map_store(o, indirect_find(sv, PL_parser->oldbufptr), sv);
 }

 return CALL_FPTR(indirect_old_ck_const)(aTHX_ o);
}

STATIC OP *(*indirect_old_ck_rv2sv)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_rv2sv(pTHX_ OP *o) {
 if (indirect_hint()) {
  OP *op = cUNOPo->op_first;
  SV *name = cSVOPx_sv(op);
  if (SvPOK(name) && (SvTYPE(name) >= SVt_PV)) {
   SV *sv = sv_2mortal(newSVpvn("$", 1));
   sv_catsv(sv, name);
   indirect_map_store(o, indirect_find(sv, PL_parser->oldbufptr), sv);
  }
 }

 return CALL_FPTR(indirect_old_ck_rv2sv)(aTHX_ o);
}

STATIC OP *(*indirect_old_ck_padany)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_padany(pTHX_ OP *o) {
 if (indirect_hint()) {
  SV *sv;
  const char *s = PL_parser->oldbufptr, *t = PL_parser->bufptr - 1;

  while (s < t && isSPACE(*s)) ++s;
  while (t > s && isSPACE(*t)) --t;
  sv = sv_2mortal(newSVpvn(s, t - s + 1));

  indirect_map_store(o, s, sv);
 }

 return CALL_FPTR(indirect_old_ck_padany)(aTHX_ o);
}

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
   s  = indirect_find(sv, PL_parser->oldbufptr);
  }
  o = CALL_FPTR(indirect_old_ck_method)(aTHX_ o);
  /* o may now be a method_named */
  indirect_map_store(o, s, sv);
  return o;
 }

done:
 return CALL_FPTR(indirect_old_ck_method)(aTHX_ o);
}

STATIC OP *(*indirect_old_ck_entersub)(pTHX_ OP *) = 0;

STATIC OP *indirect_ck_entersub(pTHX_ OP *o) {
 LISTOP *op;
 OP *om, *oo;
 UV hint = indirect_hint();

 if (hint) {
  const char *pm, *po;
  SV *svm, *svo;
  op = (LISTOP *) o;
  while (op->op_type != OP_PUSHMARK)
   op = (LISTOP *) op->op_first;
  oo = op->op_sibling;
  om = oo;
  while (om->op_sibling)
   om = om->op_sibling;
  if (om->op_type == OP_METHOD)
   om = cUNOPx(om)->op_first;
  pm = indirect_map_fetch(om, &svm);
  po = indirect_map_fetch(oo, &svo);
  if (pm && po && pm < po && indirect_intuit(pm, po))
   ((hint == 2) ? croak : warn)(indirect_msg, SvPV_nolen(svm), SvPV_nolen(svo));
 }

 return CALL_FPTR(indirect_old_ck_entersub)(aTHX_ o);
}

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
