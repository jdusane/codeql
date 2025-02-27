import codeql.ruby.security.performance.RegExpTreeView

query predicate nonUniqueChild(RegExpParent parent, int i, RegExpTerm child) {
  child = parent.getChild(i) and
  strictcount(parent.getChild(i)) > 1
}

query predicate cyclic(RegExpParent parent) { parent = parent.getAChild+() }

query predicate nonConsecutive(RegExpParent parent, int i) {
  exists(parent.getChild(i)) and
  i > 0 and
  not exists(parent.getChild(i - 1))
}
